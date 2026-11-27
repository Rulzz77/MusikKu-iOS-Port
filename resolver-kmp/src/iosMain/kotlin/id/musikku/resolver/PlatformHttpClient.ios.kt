package id.musikku.resolver

import io.ktor.client.HttpClient
import io.ktor.client.engine.darwin.Darwin
import io.ktor.client.plugins.HttpTimeout

internal actual fun createResolverHttpClient(): HttpClient =
    HttpClient(Darwin) {
        expectSuccess = false
        install(HttpTimeout) {
            requestTimeoutMillis = 30_000
            connectTimeoutMillis = 15_000
            socketTimeoutMillis = 30_000
        }
    }
