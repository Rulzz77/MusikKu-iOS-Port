package id.musikku.resolver

import com.metrolist.innertubex.extraction.PoTokenResult
import com.metrolist.innertubex.extraction.TokenProvider
import com.metrolist.innertubex.extraction.TokenProviderCapabilities
import com.metrolist.innertubex.extraction.potoken.parseIntegrityTokenData
import com.metrolist.innertubex.extraction.potoken.stringToU8
import com.metrolist.innertubex.extraction.potoken.u8ToBase64
import com.metrolist.innertubex.extraction.strategy.PoTokenProviderKind
import io.ktor.client.HttpClient
import io.ktor.client.engine.darwin.Darwin
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import platform.CoreGraphics.CGRectZero
import platform.Foundation.NSURL
import platform.WebKit.WKWebView
import platform.WebKit.WKWebViewConfiguration
import platform.WebKit.WKWebsiteDataStore
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.coroutines.suspendCancellableCoroutine
import kotlin.time.Clock
import kotlin.time.Duration.Companion.seconds
import kotlin.time.Instant

/**
 * iOS BotGuard provider. WKWebView executes the challenge JavaScript in an isolated,
 * non-persistent data store; Ktor performs the fixed HTTPS BotGuard requests.
 *
 * No Google account cookies are read, copied, stored, or sent by this provider.
 * PoTokens and integrity data are memory-only and must never be logged.
 */
internal actual fun createPlatformTokenProvider(): TokenProvider = IOSPoTokenProvider()

private class IOSPoTokenProvider : TokenProvider {
    override val capabilities = TokenProviderCapabilities(
        providers = setOf(PoTokenProviderKind.WEB_BOTGUARD),
        usesWebView = true
    )

    private val mutex = Mutex()
    private val httpClient = HttpClient(Darwin) {
        expectSuccess = false
        followRedirects = false
        install(HttpTimeout) {
            requestTimeoutMillis = 30_000
            connectTimeoutMillis = 15_000
            socketTimeoutMillis = 30_000
        }
    }

    private var activeSession: IOSBotGuardSession? = null
    private var activeVisitorData: String? = null
    private var cachedVisitorToken: String? = null

    override suspend fun getPoToken(
        videoId: String,
        visitorData: String,
        cookie: String?
    ): PoTokenResult? {
        if (visitorData.isBlank() || visitorData.length > MAX_VISITOR_DATA_LENGTH) return null
        if (!videoId.matches(Regex("^[A-Za-z0-9_-]{11}$"))) return null

        return mutex.withLock {
            var lastFailure: Throwable? = null

            repeat(2) { attempt ->
                try {
                    ensureSession(visitorData)
                    val session = activeSession ?: error("BotGuard session was not created")

                    val visitorToken = cachedVisitorToken
                        ?: session.generatePoToken(visitorData).also { cachedVisitorToken = it }
                    val videoToken = session.generatePoToken(videoId)

                    // InnerTubeX maps VISITOR_DATA to playerRequestToken and VIDEO_ID
                    // to streamingDataToken. Keep the same mapping as MusikKu Android.
                    return@withLock PoTokenResult(
                        playerRequestToken = visitorToken,
                        streamingDataToken = videoToken,
                        visitorData = visitorData
                    )
                } catch (error: CancellationException) {
                    throw error
                } catch (error: Throwable) {
                    lastFailure = error
                    clearSession()
                    if (attempt == 1) {
                        throw IllegalStateException("iOS BotGuard token generation failed", error)
                    }
                }
            }

            lastFailure?.let {
                throw IllegalStateException("iOS BotGuard token generation failed", it)
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

    private suspend fun ensureSession(visitorData: String) {
        val current = activeSession
        if (current == null || activeVisitorData != visitorData || current.isExpired) {
            clearSession()
            val created = IOSBotGuardSession.create(httpClient)
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

private class IOSBotGuardSession private constructor(
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
        check(!closed) { "BotGuard WebView is closed" }
        require(identifier.isNotBlank() && identifier.length <= MAX_IDENTIFIER_LENGTH) {
            "BotGuard token identifier is invalid"
        }

        requestCounter += 1
        val requestKey = "mk$requestCounter"
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
                val error = evaluate("String((window.__mkTokenErrors || {})[$keyLiteral] || '')").asText()
                if (error.isNotBlank()) {
                    throw IllegalStateException("BotGuard could not mint a token")
                }
                val result = evaluate("String((window.__mkTokenResults || {})[$keyLiteral] || '')").asText()
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

    private suspend fun initialize() {
        awaitJavaScriptRuntime()

        val createBody = JsonArray(listOf(JsonPrimitive(REQUEST_KEY))).toString()
        val createResponse = postBotGuard(CREATE_URL, createBody, MAX_CREATE_RESPONSE_CHARS)
        val challengeJson = parseCreateChallenge(createResponse)

        evaluate(
            """
            (function () {
              window.__mkPhase = "running";
              window.__mkError = "";
              try {
                window.data = $challengeJson;
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
            throw IllegalStateException("BotGuard challenge returned no response")
        }

        val integrityBody = JsonArray(
            listOf(JsonPrimitive(REQUEST_KEY), JsonPrimitive(botguardResponse))
        ).toString()
        val integrityResponse = postBotGuard(GENERATE_IT_URL, integrityBody, MAX_INTEGRITY_RESPONSE_CHARS)
        val integrity = parseIntegrityTokenData(integrityResponse)

        evaluate(
            """
            (function () {
              window.__mkPhase = "minter";
              try {
                window.__mkIntegrityToken = ${integrity.tokenJavaScript};
                createPoTokenMinter(window.__mkWebPoSignalOutput, window.__mkIntegrityToken).then(function () {
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

        val marginSeconds = minOf(600L, (integrity.lifetimeSeconds / 10L).coerceAtLeast(30L))
        val usableLifetime = (integrity.lifetimeSeconds - marginSeconds).coerceAtLeast(1L)
        expiresAt = Clock.System.now() + usableLifetime.seconds
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
                    // Do not expose or log the challenge payload or token values.
                    throw IllegalStateException("BotGuard JavaScript challenge failed")
                }
                if (phase == expected) return@withTimeout
                delay(POLL_INTERVAL_MS)
            }
        }
    }

    private suspend fun postBotGuard(url: String, body: String, maxChars: Int): String {
        val response = httpClient.post(url) {
            header(HttpHeaders.UserAgent, userAgent)
            header(HttpHeaders.Accept, "application/json")
            header(HttpHeaders.ContentType, "application/json+protobuf")
            header("x-goog-api-key", GOOGLE_API_KEY)
            header("x-user-agent", "grpc-web-javascript/0.1")
            setBody(body)
        }

        if (response.status != HttpStatusCode.OK) {
            throw IllegalStateException("BotGuard request failed with HTTP ${response.status.value}")
        }
        val responseBody = response.bodyAsText()
        if (responseBody.isBlank() || responseBody.length > maxChars) {
            throw IllegalStateException("BotGuard response was empty or exceeded its size limit")
        }
        return responseBody
    }

    private suspend fun evaluate(script: String): Any? = withContext(Dispatchers.Main) {
        if (closed) throw IllegalStateException("BotGuard WebView is closed")
        suspendCancellableCoroutine { continuation ->
            webView.evaluateJavaScript(script) { result, error ->
                if (!continuation.isActive) return@evaluateJavaScript
                if (error != null) {
                    continuation.resumeWithException(
                        IllegalStateException(
                            "WKWebView JavaScript evaluation failed: " + error.localizedDescription
                        )
                    )
                } else {
                    continuation.resume(result)
                }
            }
        }
    }

    private fun Any?.asText(): String = this?.toString().orEmpty()

    companion object {
        private const val CREATE_URL = "https://www.youtube.com/api/jnn/v1/Create"
        private const val GENERATE_IT_URL = "https://www.youtube.com/api/jnn/v1/GenerateIT"
        private const val GOOGLE_API_KEY = "AIzaSyDyT5W0Jh49F30Pqqtyfdf7pDLFKLJoAnw"
        private const val REQUEST_KEY = "O43z0dpjhgX20SCx4KAo"
        private const val PAGE_LOAD_TIMEOUT_MS = 15_000L
        private const val BOTGUARD_TIMEOUT_MS = 30_000L
        private const val MINTER_TIMEOUT_MS = 15_000L
        private const val TOKEN_TIMEOUT_MS = 12_000L
        private const val POLL_INTERVAL_MS = 100L
        private const val MAX_CREATE_RESPONSE_CHARS = 4 * 1024 * 1024
        private const val MAX_INTEGRITY_RESPONSE_CHARS = 1024 * 1024
        private const val MAX_IDENTIFIER_LENGTH = 1024

        suspend fun create(httpClient: HttpClient): IOSBotGuardSession {
            val webView = withContext(Dispatchers.Main) {
                val configuration = WKWebViewConfiguration()
                configuration.websiteDataStore = WKWebsiteDataStore.nonPersistentDataStore()
                WKWebView(frame = CGRectZero, configuration = configuration).apply {
                    loadHTMLString(IOS_PO_TOKEN_HTML, NSURL(string = "https://www.youtube.com"))
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

            val session = IOSBotGuardSession(webView, userAgent, httpClient)
            try {
                session.initialize()
                return session
            } catch (error: Throwable) {
                session.close()
                throw error
            }
        }
    }
}

@OptIn(kotlin.io.encoding.ExperimentalEncodingApi::class)
private fun parseCreateChallenge(rawResponse: String): String {
    val outer = Json.parseToJsonElement(rawResponse).jsonArray
    val second = outer.getOrNull(1)
    val challenge = if (second is JsonPrimitive && second.isString) {
        Json.parseToJsonElement(descrambleChallenge(second.content)).jsonArray
    } else {
        outer.getOrNull(0)?.jsonArray
            ?: throw IllegalStateException("BotGuard response did not contain challenge data")
    }

    if (challenge.size < 8) {
        throw IllegalStateException("BotGuard challenge response was incomplete")
    }

    fun firstString(value: JsonElement): JsonElement? = when (value) {
        is JsonArray -> value.firstOrNull { it is JsonPrimitive && it.isString }
        is JsonPrimitive -> if (value.isString) value else null
        else -> null
    }

    val javascript = firstString(challenge[1]) ?: JsonNull
    val trustedResource = firstString(challenge[2]) ?: JsonNull
    val payload = buildJsonObject {
        put("messageId", challenge[0])
        put(
            "interpreterJavascript",
            buildJsonObject {
                put("privateDoNotAccessOrElseSafeScriptWrappedValue", javascript)
                put("privateDoNotAccessOrElseTrustedResourceUrlWrappedValue", trustedResource)
            }
        )
        put("interpreterHash", challenge[3])
        put("program", challenge[4])
        put("globalName", challenge[5])
        put("clientExperimentsStateBlob", challenge[7])
    }
    return payload.toString()
}

@OptIn(kotlin.io.encoding.ExperimentalEncodingApi::class)
private fun descrambleChallenge(value: String): String {
    val normalized = value
        .replace('-', '+')
        .replace('_', '/')
        .replace('.', '=')
    val padded = normalized + "=".repeat((4 - normalized.length % 4) % 4)
    val decoded = kotlin.io.encoding.Base64.Default.decode(padded)
    return decoded.map { byte -> (byte.toInt() + 97).toByte() }.toByteArray().decodeToString()
}
