import org.jetbrains.kotlin.gradle.plugin.mpp.apple.XCFramework

plugins {
    id("org.jetbrains.kotlin.multiplatform") version "2.4.10"
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
            // Use the exact resolver version already used by MusikKu Android.
            implementation("com.github.MetrolistGroup.innertubex:innertubex:v0.7.0")
        }

        iosMain.dependencies {
            implementation("io.ktor:ktor-client-darwin:3.5.2")
        }
    }
}
