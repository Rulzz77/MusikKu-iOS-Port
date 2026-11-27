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
            // Use the exact resolver version already used by MusikKu Android.
            implementation("com.github.MetrolistGroup.innertubex:innertubex:v0.7.0")
            // InnerTubeX v0.7.0 requests QuickJS 1.0.14 transitively. Override it with
            // the upstream release that pins the native iOS deployment target.
            implementation("io.github.dokar3:quickjs-kt:1.0.18")
        }

        iosMain.dependencies {
            implementation("io.ktor:ktor-client-darwin:3.5.2")
        }
    }
}
