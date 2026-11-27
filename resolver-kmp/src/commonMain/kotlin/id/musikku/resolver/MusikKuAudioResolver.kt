package id.musikku.resolver

import com.metrolist.innertubex.InnerTube
import com.metrolist.innertubex.cipher.PlayerConfigRepository
import com.metrolist.innertubex.cipher.RemotePlayerConfigStore
import com.metrolist.innertubex.cipher.YouTubeCipherService
import com.metrolist.innertubex.extraction.AudioQuality
import com.metrolist.innertubex.extraction.ContentHints
import com.metrolist.innertubex.extraction.InnerTubeExtractor
import com.metrolist.innertubex.extraction.YtConfigParserImpl
import com.metrolist.innertubex.extraction.generateClientPlaybackNonce
import com.metrolist.innertubex.models.YouTubeLocale
import io.ktor.client.HttpClient
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * Audio-only resolver shared with the Android MusikKu implementation through
 * the same InnerTubeX KMP library version. SABR and HLS are intentionally
 * disabled because AVPlayer consumes direct HTTP audio assets.
 *
 * Remote player configs are cached persistently on iOS so cipher changes can
 * be refreshed without requiring an app update. The platform supplies an
 * initial WEB_BOTGUARD token provider; attestation-gated streams may still be
 * refused when the live challenge cannot be initialized or completed.
 */
class MusikKuAudioResolver {
    private val httpClient: HttpClient = createResolverHttpClient()
    private val innerTube = InnerTube(httpClient)
    private val configStore = RemotePlayerConfigStore(
        httpClient = httpClient,
        repository = createPlatformPlayerConfigRepository()
    )
    private val cipherService = YouTubeCipherService(httpClient, configStore)
    private val configParser = YtConfigParserImpl(httpClient, innerTube, configStore)
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
     * The iOS host may mint short-lived WEB_BOTGUARD tokens in an isolated
     * WKWebView session. No Google account cookie is attached to the request.
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
            allowBoundedRange = true
        )

        val stream = extractor.extract(
            videoId = videoId,
            hints = hints,
            audioQuality = audioQuality,
            clientPlaybackNonce = generateClientPlaybackNonce()
        ) ?: return null

        val url = stream.audioUrl
        require(url.startsWith("https://", ignoreCase = true)) {
            "The resolver did not return a secure HTTPS audio URL"
        }
        require(stream.mimeType?.startsWith("audio/mp4", ignoreCase = true) == true) {
            "The selected stream is not an AVPlayer-compatible MP4 audio stream."
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

    fun close() {
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
