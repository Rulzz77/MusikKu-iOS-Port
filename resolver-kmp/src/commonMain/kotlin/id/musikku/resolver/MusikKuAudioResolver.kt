package id.musikku.resolver

import com.metrolist.innertubex.InnerTube
import com.metrolist.innertubex.cipher.PlayerConfigRepository
import com.metrolist.innertubex.cipher.RemotePlayerConfigStore
import com.metrolist.innertubex.cipher.YouTubeCipherService
import com.metrolist.innertubex.extraction.AudioQuality
import com.metrolist.innertubex.extraction.ContentHints
import com.metrolist.innertubex.extraction.InnerTubeExtractor
import com.metrolist.innertubex.extraction.YtConfigParser
import com.metrolist.innertubex.extraction.YtConfigParserImpl
import com.metrolist.innertubex.extraction.generateClientPlaybackNonce
import com.metrolist.innertubex.models.YouTubeLocale
import io.ktor.client.HttpClient
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlin.time.TimeMark
import kotlin.time.TimeSource

/**
 * Audio-only resolver shared with the Android MusikKu implementation through
 * InnerTubeX v0.13.2 for the iOS target. The Android repository remains
 * separate and unchanged. SABR and HLS are intentionally disabled because
 * AVPlayer consumes direct HTTP audio assets.
 *
 * Remote player configs are cached persistently on iOS so cipher changes can
 * be refreshed without requiring an app update. The platform supplies an
 * anonymous WEBPAGE_ATTESTATION provider backed by a non-persistent WKWebView;
 * live challenge and media compatibility still require physical-device tests.
 */
class MusikKuAudioResolver {
    private val httpClient: HttpClient = createResolverHttpClient()
    private val innerTube = InnerTube(httpClient)
    private val configStore = RemotePlayerConfigStore(
        httpClient = httpClient,
        repository = createPlatformPlayerConfigRepository()
    )
    private val cipherService = YouTubeCipherService(httpClient, configStore)
    private val configParser = YtConfigParserImpl(httpClient, innerTube, configStore).withEmbeddedConfigFallback()
    private val failedProfileMutex = Mutex()
    private val failedStreamProfiles = mutableMapOf<String, MutableMap<String, TimeMark>>()
    private val recoveryScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val tokenProvider = createPlatformTokenProvider()
    private val extractor = InnerTubeExtractor(
        configParser = configParser,
        cipherService = cipherService,
        innerTube = innerTube,
        tokenProvider = tokenProvider
    )

    /**
     * Preloads player configuration and cipher support before the first play.
     * This reduces the cold-start work performed after the user taps a track.
     */
    @Throws(Exception::class)
    suspend fun prewarm(
        language: String = "id",
        region: String = "ID"
    ) {
        innerTube.locale = YouTubeLocale(
            gl = region.uppercase(),
            hl = language.lowercase()
        )
        extractor.prewarm()
    }

    /**
     * Resolves a YouTube Music video ID to a direct HTTPS audio URL and the
     * request headers required by its selected playback client.
     *
     * The iOS host may mint short-lived Webpage Attestation tokens in an isolated
     * WKWebView session. No account cookie is attached to the request.
     */
    @Throws(Exception::class)
    suspend fun resolve(
        videoId: String,
        language: String = "id",
        region: String = "ID",
        quality: String = "high"
    ): ResolvedAudioStream? {
        require(videoId.matches(Regex("^[A-Za-z0-9_-]{11}$"))) {
            "Invalid YouTube video ID"
        }

        innerTube.locale = YouTubeLocale(
            gl = region.uppercase(),
            hl = language.lowercase()
        )

        // AVPlayer is most reliable with YouTube's audio/mp4 (M4A/AAC)
        // representation. InnerTubeX HIGH may prefer audio/webm/Opus, so use
        // its MP4 selector for the normal and automatic iOS quality modes.
        val audioQuality = when (quality.lowercase()) {
            "low" -> AudioQuality.LOW
            else -> AudioQuality.MP4
        }

        val hints = ContentHints(wantVideo = false).withStreamCapabilities(
            allowHls = false,
            allowSabr = false,
            allowBoundedRange = true,
            // Last-resort iOS Producer returns a muxed MP4 with AAC audio. AVPlayer
            // can play that file without attaching a video layer, after direct audio fails.
            allowProgressive = true
        )

        val excludedClients = failedStreamClients(videoId)
        val stream = extractor.extract(
            videoId = videoId,
            hints = hints,
            excludedClients = excludedClients,
            audioQuality = audioQuality,
            clientPlaybackNonce = generateClientPlaybackNonce()
        ) ?: return null

        val url = stream.audioUrl
        require(url.startsWith("https://", ignoreCase = true)) {
            "The resolver did not return a secure HTTPS audio URL"
        }
        val mimeType = stream.mimeType?.substringBefore(';')?.trim().orEmpty()
        val isAudioOnlyMp4 = mimeType.equals("audio/mp4", ignoreCase = true)
        val isMuxedMp4WithAac = mimeType.equals("video/mp4", ignoreCase = true) &&
            stream.codecs?.contains("mp4a", ignoreCase = true) == true
        require(isAudioOnlyMp4 || isMuxedMp4WithAac) {
            "The selected stream is not an AVPlayer-compatible AAC MP4 stream."
        }

        return ResolvedAudioStream(
            url = url,
            mimeType = stream.mimeType,
            codecs = stream.codecs,
            bitrate = stream.bitrate,
            headersJson = Json.encodeToString(stream.headers),
            clientName = stream.clientName,
            profileId = stream.profileId
        )
    }

    /**
     * Records a profile refused by AVPlayer. InnerTubeX excludes profile IDs (not display client names)
     * on the next extraction, matching the Android resolver's source-failure handling.
     */
    @Throws(Exception::class)
    suspend fun markStreamProfileFailed(videoId: String, profileId: String) {
        require(videoId.matches(Regex("^[A-Za-z0-9_-]{11}$"))) { "Invalid YouTube video ID" }
        val safeProfileId = profileId.trim()
        require(safeProfileId.isNotEmpty() && safeProfileId.length <= 128) {
            "Invalid stream profile ID"
        }

        failedProfileMutex.withLock {
            val profiles = failedStreamProfiles.getOrPut(videoId) { linkedMapOf() }
            profiles.entries.removeAll {
                it.value.elapsedNow().inWholeMilliseconds >= STREAM_PROFILE_FAILURE_TTL_MS
            }
            profiles[safeProfileId] = TimeSource.Monotonic.markNow()

            failedStreamProfiles.entries.removeAll { (_, entries) ->
                entries.entries.removeAll {
                    it.value.elapsedNow().inWholeMilliseconds >= STREAM_PROFILE_FAILURE_TTL_MS
                }
                entries.isEmpty()
            }
            while (failedStreamProfiles.size > MAX_FAILED_STREAM_ENTRIES) {
                failedStreamProfiles.remove(failedStreamProfiles.keys.first())
            }
        }

        // Android refreshes cipher data after a media URL is refused. Run this off the playback/UI path.
        recoveryScope.launch {
            runCatching { cipherService.refreshAfterStreamRejection() }
        }
    }

    private suspend fun failedStreamClients(videoId: String): Set<String> =
        failedProfileMutex.withLock {
            val profiles = failedStreamProfiles[videoId] ?: return@withLock emptySet()
            profiles.entries.removeAll {
                it.value.elapsedNow().inWholeMilliseconds >= STREAM_PROFILE_FAILURE_TTL_MS
            }
            if (profiles.isEmpty()) {
                failedStreamProfiles.remove(videoId)
                emptySet()
            } else {
                profiles.keys.toSet()
            }
        }

    fun close() {
        recoveryScope.cancel()
        innerTube.close()
        httpClient.close()
    }

    /** Closes the attestation runtime and its isolated WebKit session. */
    @Throws(Exception::class)
    suspend fun closeAsync() {
        tokenProvider.close()
        close()
    }
}
 
/**
 * Matches the production Metrolist resolver fallback: if the regular watch-page
 * parser cannot obtain a usable player config, retry with YouTube's embedded page.
 * This is still an anonymous request; the iOS token provider never sends account cookies.
 */
private fun YtConfigParser.withEmbeddedConfigFallback(): YtConfigParser =
    object : YtConfigParser by this {
        override suspend fun fetchConfig(
            videoId: String,
            useLoginCookies: Boolean,
        ): com.metrolist.innertubex.extraction.PlayerConfig =
            try {
                this@withEmbeddedConfigFallback.fetchConfig(videoId, useLoginCookies)
            } catch (error: CancellationException) {
                throw error
            } catch (_: Exception) {
                // Watch-page requests can fail through timeouts and transport errors too.
                // Retry the independent embedded-page config without any account cookies.
                this@withEmbeddedConfigFallback.fetchEmbeddedConfig(
                    videoId = videoId,
                    useLoginCookies = false,
                )
            }
    }

private const val STREAM_PROFILE_FAILURE_TTL_MS = 10 * 60 * 1000L
private const val MAX_FAILED_STREAM_ENTRIES = 256

data class ResolvedAudioStream(
    val url: String,
    val mimeType: String?,
    val codecs: String?,
    val bitrate: Int?,
    val headersJson: String,
    val clientName: String,
    val profileId: String
)

internal expect fun createResolverHttpClient(): HttpClient

internal expect fun createPlatformPlayerConfigRepository(): PlayerConfigRepository
