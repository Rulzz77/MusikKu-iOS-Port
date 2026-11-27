import org.jetbrains.kotlin.gradle.plugin.mpp.apple.XCFramework

plugins {
    id("org.jetbrains.kotlin.multiplatform") version "2.4.21"
}

kotlin {
    val resolverFramework = XCFramework("MusikKuResolverKit")

    iosArm64().binaries.framework {
        baseName = "MusikKuResolverKit"
        isStatic = true
        resolverFramework.add(this)
    }

    iosSimulatorArm64().binaries.framework {
        baseName = "MusikKuResolverKit"
        isStatic = true
        resolverFramework.add(this)
    }

    jvmToolchain(21)

    sourceSets {
        commonMain.dependencies {
            // iOS uses the current shared resolver to pick up native cipher and stream fixes.
            // Android's app repository remains unchanged.
            implementation("com.github.MetrolistGroup.innertubex:innertubex:v0.13.2")
        }

        iosMain.dependencies {
            implementation("io.ktor:ktor-client-darwin:3.6.0")
        }
    }
}
