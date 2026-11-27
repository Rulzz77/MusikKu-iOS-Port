package id.musikku.resolver

import com.metrolist.innertubex.InnerTube
import com.metrolist.innertubex.cipher.PlayerConfigRepository
import com.metrolist.innertubex.cipher.RemotePlayerConfigStore
import com.metrolist.innertubex.cipher.YouTubeCipherService
import com.metrolist.innertubex.extraction.AudioQuality
import com.metrolist.innertubex.extraction.ContentHints
import com.metrolist.innertubex.extraction.InnerTubeExtractor
import com.metrolist.innertubex.extraction.YtConfigParserImpl
import com.metrolist.innertubex.models.YouTubeLocale
import io.ktor.client.HttpClient
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * Audio-only resolver shared with the Android MusikKu implementation through
 * the same InnerTubeX KMP library version. SABR and HLS are intentionally
 * disabled because AVPlayer consumes direct HTTP audio assets.
 */
class MusikKuAudioResolver {
    private val httpClient: HttpClient = createResolverHttpClient()
    private val innerTube = InnerTube(httpClient)
    private val configStore = RemotePlayerConfigStore(
        httpClient = httpClient,
        repository = PlayerConfigRepository.disabled()
    )
    private val cipherService = YouTubeCipherService(httpClient, configStore)
    private val configParser = YtConfigParserImpl(httpClient, innerTube, configStore)
    private val extractor = InnerTubeExtractor(
        configParser = configParser,
        cipherService = cipherService,
        innerTube = innerTube
    )

    /**
     * Resolves a YouTube Music video ID to a direct audio URL and the request
     * headers required by its selected playback client.
     *
     * This method does not use an account cookie and does not mint a PoToken.
     * When YouTube requires a platform attestation token, the resolver can
     * return null; the iOS host must then show a retry/unsupported message.
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

        val audioQuality = when (quality.lowercase()) {
            "low" -> AudioQuality.LOW
            "auto" -> AudioQuality.AUTO
            else -> AudioQuality.HIGH
        }

        val hints = ContentHints(wantVideo = false).withStreamCapabilities(
            allowHls = false,
            allowSabr = false,
            allowBoundedRange = true
        )

        val stream = extractor.extract(
            videoId = videoId,
            hints = hints,
            audioQuality = audioQuality
        ) ?: return null

        val url = stream.audioUrl
        require(url.startsWith("https://", ignoreCase = true)) {
            "The resolver did not return a secure HTTPS audio URL"
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
