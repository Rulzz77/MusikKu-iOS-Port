package id.musikku.resolver

import com.metrolist.innertubex.extraction.TokenProvider

/**
 * Returns the platform-owned attestation provider.
 *
 * The provider owns its token/session lifecycle; credentials and token values
 * must never be logged or persisted in the app's library.
 */
internal expect fun createPlatformTokenProvider(): TokenProvider
