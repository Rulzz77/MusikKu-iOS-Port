package id.musikku.resolver

import com.metrolist.innertubex.bodyAsTextLimited
import com.metrolist.innertubex.extraction.PoTokenResult
import com.metrolist.innertubex.extraction.TokenProvider
import com.metrolist.innertubex.extraction.TokenProviderCapabilities
import com.metrolist.innertubex.extraction.potoken.parseAttestationChallengeData
import com.metrolist.innertubex.extraction.potoken.parseAttestationInterpreterUrl
import com.metrolist.innertubex.extraction.potoken.parseIntegrityTokenData
import com.metrolist.innertubex.extraction.potoken.parseWebPageAttestationContext
import com.metrolist.innertubex.extraction.potoken.requireTrustedAttestationInterpreterUrl
import com.metrolist.innertubex.extraction.potoken.stringToU8
import com.metrolist.innertubex.extraction.potoken.u8ToBase64
import com.metrolist.innertubex.extraction.strategy.PoTokenProviderKind
import io.ktor.client.HttpClient
import io.ktor.client.engine.darwin.Darwin
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.request.contentType
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.parameter
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.isSuccess
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.isActive
import kotlinx.coroutines.delay
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonPrimitive
import platform.CoreGraphics.CGRectMake
import platform.Foundation.NSURL
import platform.WebKit.WKWebView
import platform.WebKit.WKWebViewConfiguration
import platform.WebKit.WKWebsiteDataStore
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.time.Clock
import kotlin.time.Duration.Companion.seconds
import kotlin.time.Instant

/**
 * Anonymous Webpage Attestation provider.
 *
 * WKWebView runs the challenge in a non-persistent data store. Ktor fetches the
 * watch page and trusted interpreter over HTTPS and exchanges the integrity
 * response. Only the static consent cookie SOCS=CAI is sent; account cookies
 * are rejected and never read, copied, persisted, or transmitted.
 *
 * Visitor/video PO tokens remain memory-only and must never be logged.
 */
internal actual fun createPlatformTokenProvider(): TokenProvider = IOSPoTokenProvider()

@OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)
private class IOSPoTokenProvider : TokenProvider {
    override val capabilities = TokenProviderCapabilities(
        providers = setOf(PoTokenProviderKind.WEBPAGE_ATTESTATION),
        usesWebView = true
    )

    private val mutex = Mutex()
    private val httpClient = HttpClient(Darwin) {
        expectSuccess = false
        followRedirects = false
        engine {
            configureSession {
                HTTPCookieStorage = null
                HTTPShouldSetCookies = false
            }
        }
        install(HttpTimeout) {
            requestTimeoutMillis = 30_000
            connectTimeoutMillis = 15_000
            socketTimeoutMillis = 30_000
        }
    }

    private var activeSession: IOSWebAttestationSession? = null
    private var activeVisitorData: String? = null
    private var cachedVisitorToken: String? = null

    override suspend fun getPoToken(
        videoId: String,
        visitorData: String,
        cookie: String?
    ): PoTokenResult? {
        if (!cookie.isNullOrBlank()) {
            throw IllegalStateException("The iOS attestation provider only supports anonymous sessions")
        }
        if (visitorData.isBlank() ||
            visitorData.length > MAX_VISITOR_DATA_LENGTH ||
            visitorData.any { it.code !in 0x21..0x7e }
        ) return null
        if (!videoId.matches(Regex("^[A-Za-z0-9_-]{11}$"))) return null

        return mutex.withLock {
            var lastFailure: Exception? = null

            repeat(2) { attempt ->
                try {
                    ensureSession(videoId, visitorData)
                    val session = activeSession ?: error("Webpage attestation session was not created")
                    val visitorToken = cachedVisitorToken
                        ?: session.generatePoToken(visitorData).also { cachedVisitorToken = it }
                    val videoToken = session.generatePoToken(videoId)

                    return@withLock PoTokenResult(
                        playerRequestToken = visitorToken,
                        streamingDataToken = videoToken,
                        visitorData = visitorData
                    )
                } catch (error: TimeoutCancellationException) {
                    if (!currentCoroutineContext().isActive) throw error
                    withContext(NonCancellable) { clearSession() }
                    throw IllegalStateException("iOS webpage attestation timed out", error)
                } catch (error: CancellationException) {
                    withContext(NonCancellable) { clearSession() }
                    throw error
                } catch (error: Exception) {
                    lastFailure = error
                    clearSession()
                    if (attempt == 1) {
                        throw IllegalStateException("iOS webpage attestation failed", error)
                    }
                }
            }

            lastFailure?.let {
                throw IllegalStateException("iOS webpage attestation failed", it)
            }
            null
        }
    }

    override suspend fun invalidateAttestation() {
        mutex.withLock { clearSession() }
    }

    override suspend fun close() {
        mutex.withLock {
            clearSession()
            httpClient.close()
        }
    }

    private suspend fun ensureSession(videoId: String, visitorData: String) {
        val current = activeSession
        if (current == null || activeVisitorData != visitorData || current.isExpired) {
            clearSession()
            val created = IOSWebAttestationSession.create(httpClient, videoId, visitorData)
            activeSession = created
            activeVisitorData = visitorData
            cachedVisitorToken = null
        }
    }

    private suspend fun clearSession() {
        val current = activeSession
        activeSession = null
        activeVisitorData = null
        cachedVisitorToken = null
        current?.close()
    }

    private companion object {
        const val MAX_VISITOR_DATA_LENGTH = 4096
    }
}

@OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)
private class IOSWebAttestationSession private constructor(
    private val webView: WKWebView,
    private val userAgent: String,
    private val httpClient: HttpClient
) {
    private var expiresAt: Instant = Clock.System.now()
    private var closed = false
    private var requestCounter = 0L

    val isExpired: Boolean
        get() = closed || Clock.System.now() >= expiresAt

    suspend fun generatePoToken(identifier: String): String {
        check(!closed) { "Attestation WebView is closed" }
        require(identifier.isNotBlank() && identifier.length <= MAX_IDENTIFIER_LENGTH) {
            "Attestation token identifier is invalid"
        }

        requestCounter += 1
        val requestKey = "mk" + requestCounter
        val keyLiteral = JsonPrimitive(requestKey).toString()
        val identifierExpression = stringToU8(identifier)

        val script = """
            (function () {
              var key = $keyLiteral;
              try {
                window.__mkTokenResults = window.__mkTokenResults || Object.create(null);
                window.__mkTokenErrors = window.__mkTokenErrors || Object.create(null);
                obtainPoToken($identifierExpression).then(function (token) {
                  window.__mkTokenResults[key] = Array.prototype.join.call(token, ",");
                }).catch(function (error) {
                  window.__mkTokenErrors[key] = String(error && error.message ? error.message : error);
                });
              } catch (error) {
                window.__mkTokenErrors[key] = String(error && error.message ? error.message : error);
              }
            })();
        """.trimIndent()

        evaluate(script)
        val rawBytes = withTimeout(TOKEN_TIMEOUT_MS) {
            while (true) {
                val error = evaluate(
                    "(function () { var map = window.__mkTokenErrors || {}; var value = map[$keyLiteral] || ''; delete map[$keyLiteral]; return String(value); })()"
                ).asText()
                if (error.isNotBlank()) {
                    throw IllegalStateException("Webpage attestation could not mint a token")
                }
                val result = evaluate(
                    "(function () { var map = window.__mkTokenResults || {}; var value = map[$keyLiteral] || ''; delete map[$keyLiteral]; return String(value); })()"
                ).asText()
                if (result.isNotBlank()) return@withTimeout result
                delay(POLL_INTERVAL_MS)
            }
            @Suppress("UNREACHABLE_CODE")
            ""
        }

        return u8ToBase64(rawBytes)
    }

    suspend fun close() {
        if (closed) return
        closed = true
        withContext(Dispatchers.Main) {
            runCatching {
                webView.stopLoading()
                webView.loadHTMLString("", null)
                webView.removeFromSuperview()
            }
        }
    }

    private suspend fun initialize(videoId: String, visitorData: String) {
        awaitJavaScriptRuntime()

        val watchPage = fetchWatchPage(videoId, visitorData)
        val attestation = parseWebPageAttestationContext(watchPage)
        val interpreterUrl = requireTrustedAttestationInterpreterUrl(
            parseAttestationInterpreterUrl(attestation.challenge)
        )
        val interpreterJavascript = fetchInterpreter(interpreterUrl)
        val challengeData = parseAttestationChallengeData(
            attestation.challenge,
            interpreterJavascript
        )
        val eventIdLiteral = JsonPrimitive(attestation.eventId).toString()

        evaluate(
            """
            (function () {
              window.yt = { config_: { EVENT_ID: $eventIdLiteral } };
              window.__mkPhase = "running";
              window.__mkError = "";
              try {
                window.data = $challengeData;
                runBotGuard(window.data).then(function (result) {
                  window.__mkWebPoSignalOutput = result.webPoSignalOutput;
                  window.__mkBotguardResponse = result.botguardResponse;
                  window.__mkPhase = "botguard-ready";
                }).catch(function (error) {
                  window.__mkError = String(error && error.message ? error.message : error);
                  window.__mkPhase = "error";
                });
              } catch (error) {
                window.__mkError = String(error && error.message ? error.message : error);
                window.__mkPhase = "error";
              }
            })();
            """.trimIndent()
        )
        waitForPhase("botguard-ready", BOTGUARD_TIMEOUT_MS)

        val botguardResponse = evaluate("String(window.__mkBotguardResponse || '')").asText()
        if (botguardResponse.isBlank()) {
            throw IllegalStateException("Webpage attestation returned no BotGuard response")
        }

        val integrityBody = JsonArray(
            listOf(JsonPrimitive(REQUEST_KEY), JsonPrimitive(botguardResponse))
        ).toString()
        val integrityResponse = postGenerateIntegrityToken(integrityBody)
        val integrity = parseIntegrityTokenData(integrityResponse)
        require(integrity.lifetimeSeconds > 1L) { "Integrity token lifetime was invalid" }

        val integrityTokenJavaScript = integrity.tokenJavaScript
        evaluate(
            """
            (function () {
              window.__mkPhase = "minter";
              try {
                createPoTokenMinter(window.__mkWebPoSignalOutput, $integrityTokenJavaScript).then(function () {
                  window.__mkPhase = "ready";
                }).catch(function (error) {
                  window.__mkError = String(error && error.message ? error.message : error);
                  window.__mkPhase = "error";
                });
              } catch (error) {
                window.__mkError = String(error && error.message ? error.message : error);
                window.__mkPhase = "error";
              }
            })();
            """.trimIndent()
        )
        waitForPhase("ready", MINTER_TIMEOUT_MS)

        val lifetime = integrity.lifetimeSeconds.coerceAtMost(MAX_TOKEN_LIFETIME_SECONDS)
        val marginSeconds = minOf(600L, (lifetime / 10L).coerceAtLeast(1L))
        expiresAt = Clock.System.now() + (lifetime - marginSeconds).coerceAtLeast(1L).seconds
    }

    private suspend fun fetchWatchPage(videoId: String, visitorData: String): String {
        val response = httpClient.get(WATCH_URL) {
            parameter("v", videoId)
            header(HttpHeaders.UserAgent, userAgent)
            header(HttpHeaders.Accept, "text/html")
            header("X-Goog-Visitor-Id", visitorData)
            // A static consent preference, not an account/session credential.
            header(HttpHeaders.Cookie, CONSENT_COOKIE)
        }
        if (!response.status.isSuccess()) {
            throw IllegalStateException("YouTube watch page returned HTTP " + response.status.value)
        }
        return response.bodyAsTextLimited(MAX_WATCH_PAGE_BYTES)
    }

    private suspend fun fetchInterpreter(url: String): String {
        val response = httpClient.get(url) {
            header(HttpHeaders.UserAgent, userAgent)
            header(HttpHeaders.Accept, "*/*")
            header(HttpHeaders.Referer, YOUTUBE_REFERER)
        }
        if (!response.status.isSuccess()) {
            throw IllegalStateException("BotGuard interpreter returned HTTP " + response.status.value)
        }
        return response.bodyAsTextLimited(MAX_INTERPRETER_BYTES)
    }

    private suspend fun postGenerateIntegrityToken(body: String): String {
        val response = httpClient.post(GENERATE_IT_URL) {
            header(HttpHeaders.UserAgent, userAgent)
            header(HttpHeaders.Accept, "application/json")
            header("x-goog-api-key", GOOGLE_API_KEY)
            header("x-user-agent", "grpc-web-javascript/0.1")
            contentType(ContentType.parse("application/json+protobuf"))
            setBody(body)
        }
        if (!response.status.isSuccess()) {
            throw IllegalStateException("BotGuard integrity endpoint returned HTTP " + response.status.value)
        }
        return response.bodyAsTextLimited(MAX_INTEGRITY_RESPONSE_BYTES)
    }

    private suspend fun awaitJavaScriptRuntime() {
        withTimeout(PAGE_LOAD_TIMEOUT_MS) {
            while (true) {
                val ready = evaluate(
                    "String(typeof window.runBotGuard === 'function' && typeof window.createPoTokenMinter === 'function')"
                ).asText()
                if (ready == "true") return@withTimeout
                delay(POLL_INTERVAL_MS)
            }
        }
    }

    private suspend fun waitForPhase(expected: String, timeoutMs: Long) {
        withTimeout(timeoutMs) {
            while (true) {
                val phase = evaluate("String(window.__mkPhase || '')").asText()
                if (phase == "error") {
                    throw IllegalStateException("Webpage attestation JavaScript challenge failed")
                }
                if (phase == expected) return@withTimeout
                delay(POLL_INTERVAL_MS)
            }
        }
    }

    private suspend fun evaluate(script: String): Any? = withContext(Dispatchers.Main) {
        if (closed) throw IllegalStateException("Attestation WebView is closed")
        suspendCancellableCoroutine { continuation ->
            webView.evaluateJavaScript(script) { result, error ->
                if (!continuation.isActive) return@evaluateJavaScript
                if (error != null) {
                    continuation.resumeWithException(
                        IllegalStateException("WKWebView JavaScript evaluation failed: " + error.localizedDescription)
                    )
                } else {
                    continuation.resume(result)
                }
            }
        }
    }

    private fun Any?.asText(): String = this?.toString().orEmpty()

    companion object {
        private const val YOUTUBE_ORIGIN = "https://www.youtube.com"
        private const val YOUTUBE_REFERER = "https://www.youtube.com/"
        private const val WATCH_URL = "$YOUTUBE_ORIGIN/watch"
        private const val GENERATE_IT_URL = "$YOUTUBE_ORIGIN/api/jnn/v1/GenerateIT"
        private const val GOOGLE_API_KEY = "AIzaSyDyT5W0Jh49F30Pqqtyfdf7pDLFKLJoAnw"
        private const val REQUEST_KEY = "O43z0dpjhgX20SCx4KAo"
        private const val CONSENT_COOKIE = "SOCS=CAI"
        private const val PAGE_LOAD_TIMEOUT_MS = 15_000L
        private const val BOTGUARD_TIMEOUT_MS = 30_000L
        private const val MINTER_TIMEOUT_MS = 15_000L
        private const val TOKEN_TIMEOUT_MS = 17_000L
        private const val POLL_INTERVAL_MS = 50L
        private const val MAX_WATCH_PAGE_BYTES = 4 * 1024 * 1024
        private const val MAX_INTERPRETER_BYTES = 8 * 1024 * 1024
        private const val MAX_INTEGRITY_RESPONSE_BYTES = 1024 * 1024
        private const val MAX_IDENTIFIER_LENGTH = 1024
        private const val MAX_TOKEN_LIFETIME_SECONDS = 6 * 60 * 60L

        suspend fun create(
            httpClient: HttpClient,
            videoId: String,
            visitorData: String
        ): IOSWebAttestationSession {
            val webView = withContext(Dispatchers.Main) {
                val configuration = WKWebViewConfiguration()
                configuration.websiteDataStore = WKWebsiteDataStore.nonPersistentDataStore()
                WKWebView(
                    frame = CGRectMake(0.0, 0.0, 0.0, 0.0),
                    configuration = configuration
                ).apply {
                    loadHTMLString(IOS_PO_TOKEN_HTML, NSURL(string = YOUTUBE_ORIGIN))
                }
            }

            val userAgent = try {
                withTimeout(PAGE_LOAD_TIMEOUT_MS) {
                    var discovered: String? = null
                    while (discovered == null) {
                        val value = withContext(Dispatchers.Main) {
                            suspendCancellableCoroutine<Any?> { continuation ->
                                webView.evaluateJavaScript("navigator.userAgent") { result, error ->
                                    if (!continuation.isActive) return@evaluateJavaScript
                                    if (error != null) {
                                        continuation.resumeWithException(
                                            IllegalStateException(error.localizedDescription)
                                        )
                                    } else {
                                        continuation.resume(result)
                                    }
                                }
                            }
                        }?.toString().orEmpty()
                        if (value.isNotBlank()) {
                            discovered = value
                        } else {
                            delay(POLL_INTERVAL_MS)
                        }
                    }
                    discovered
                }
            } catch (error: Throwable) {
                withContext(Dispatchers.Main) {
                    runCatching {
                        webView.stopLoading()
                        webView.removeFromSuperview()
                    }
                }
                throw error
            }

            val session = IOSWebAttestationSession(webView, userAgent, httpClient)
            try {
                session.initialize(videoId, visitorData)
                return session
            } catch (error: Throwable) {
                session.close()
                throw error
            }
        }
    }
}
