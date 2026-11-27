package id.musikku.resolver

import com.metrolist.innertubex.cipher.PlayerConfigRepository
import platform.Foundation.NSUserDefaults

/**
 * Persists InnerTubeX's remote player config cache between app launches.
 *
 * Values are operational cache data only. No account cookies, visitor tokens,
 * PoTokens, or signed media URLs are stored here.
 */
internal class PlatformPlayerConfigRepository : PlayerConfigRepository {
    private val defaults = NSUserDefaults.standardUserDefaults

    override val enabled: Boolean = true
    override val sourceUrl: String = PLAYER_CONFIG_URL
    override val defaultSourceUrl: String = PLAYER_CONFIG_URL

    override var cachedJson: String
        get() = defaults.stringForKey(KEY_JSON) ?: ""
        set(value) {
            defaults.setObject(value, forKey = KEY_JSON)
        }

    override var cachedAtMs: Long
        get() = defaults.doubleForKey(KEY_CACHED_AT_MS).toLong()
        set(value) {
            defaults.setDouble(value.toDouble(), forKey = KEY_CACHED_AT_MS)
        }

    override var cachedSourceUrl: String
        get() = defaults.stringForKey(KEY_SOURCE_URL) ?: ""
        set(value) {
            defaults.setObject(value, forKey = KEY_SOURCE_URL)
        }

    override var cachedEtag: String
        get() = defaults.stringForKey(KEY_ETAG) ?: ""
        set(value) {
            defaults.setObject(value, forKey = KEY_ETAG)
        }

    private companion object {
        const val PLAYER_CONFIG_URL =
            "https://raw.githubusercontent.com/ZemerTeam/zemer-cipher/master/library/src/main/assets/player_configs.json"

        const val KEY_JSON = "innertubex_player_config_json"
        const val KEY_CACHED_AT_MS = "innertubex_player_config_cached_at_ms"
        const val KEY_SOURCE_URL = "innertubex_player_config_source_url"
        const val KEY_ETAG = "innertubex_player_config_etag"
    }
}


internal actual fun createPlatformPlayerConfigRepository(): PlayerConfigRepository =
    PlatformPlayerConfigRepository()
