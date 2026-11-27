package id.musikku.resolver

import io.ktor.client.HttpClient
import io.ktor.client.engine.darwin.Darwin
import io.ktor.client.plugins.HttpTimeout

internal actual fun createResolverHttpClient(): HttpClient =
    HttpClient(Darwin) {
        expectSuccess = false
        engine {
            // Resolver requests must not inherit Safari/Google account cookies from shared iOS storage.
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
