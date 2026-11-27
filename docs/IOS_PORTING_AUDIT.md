# MusikKu iOS Porting Audit

Audit target: `Rulzz77/Musikku`, default branch `main` (read-only inspection, 27 November 2026).

## Executive conclusion

A native iOS edition is technically feasible, but this is a substantial port rather than a target-switch or one-click Kotlin Multiplatform build. The current repository does not contain an iOS application target, Xcode project, iOS source sets, or iOS build workflow.

A reasonable approach is a SwiftUI iOS application with a native AVFoundation playback layer, while selectively extracting pure Kotlin domain logic into Kotlin Multiplatform `commonMain`. Do not try to compile the Android app module or its Android/JVM source sets for iOS as-is.

## Repository evidence

The inspected `main` branch contains 1,770 tree entries and the following platform structure:

| Area | Observed state |
|---|---|
| Main app | `app/`, Kotlin + Jetpack Compose, Android Gradle application plugin |
| Main activity | `app/src/main/java/com/music/bitchord/MainActivity.kt`, 6,777 lines |
| Main Android sources | About 315 Kotlin/Java files under `app/src/main/java` |
| Shared Kotlin | `shared/` has Android and JVM targets, not Apple targets |
| Shared common code | 21 Kotlin files in `shared/src/commonMain` |
| JVM-specific shared code | 101 Kotlin files in `shared/src/jvmSharedMain` |
| Shared UI | `sharedUi/` has Android and JVM targets; no Kotlin files in its `commonMain/kotlin` tree in this checkout |
| Native code | 13 C/C++/header files below the Android app CMake/JNI area, plus 29 below root `native/` |
| iOS project | No `iosApp/`, `.xcodeproj`, or dedicated iOS project files found |
| iOS CI | No iOS workflow found under `.github/workflows/` |

`shared/build.gradle.kts` declares `androidTarget {}` and `jvm {}`. Its `jvmSharedMain` source set depends on JVM libraries including OkHttp, JSoup, and JVM-compatible InnerTube/NewPipe components. `sharedUi/build.gradle.kts` similarly declares Android and JVM targets only; its shared UI implementation is currently JVM-oriented rather than an iOS UI target.

The main Android Gradle module depends on platform-specific components including AndroidX, Media3 / ExoPlayer, WorkManager, Android security crypto, Android QuickJS, Android ONNX Runtime, Google Play services (Cast and Wearable), and JNI native libraries. The Android manifest also declares foreground services, media playback, notifications, device media access, USB, and APK installation-related capabilities. These are not drop-in iOS dependencies.

## Porting architecture recommended

### iOS app shell

Use SwiftUI for the first iOS interface. This avoids forcing the existing 6,777-line Android activity and Android navigation / lifecycle APIs into a cross-platform UI rewrite. Reuse visual design tokens, icons, artwork, copy, and product behavior only after checking platform conventions.

### Playback engine

Use AVPlayer / AVQueuePlayer for ordinary remote streaming and AVAudioSession configured for the `.playback` category. Integrate `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` for lock-screen and Control Center metadata and controls. A custom AVAudioEngine-based path may be needed for real-time DSP, crossfade, equalizer, and advanced audio routing.

The AVPlayer starter in `ios/Sources/Playback/PlaybackManager.swift` is only a foundation. It is not a feature-equivalent replacement for Media3, the Android audio sink, USB-exclusive output, or the existing crossfade renderer.

### Shared Kotlin modules

Add Apple targets to selected KMP modules only after separating platform-neutral logic from platform-bound code. A typical KMP setup needs `iosArm64` for physical iPhones and `iosSimulatorArm64` for Apple Silicon Simulator builds; the Kotlin plugin then provides an `iosMain` source set. Expose a small framework to the Swift app rather than exposing the entire Android application module.

Good candidates to evaluate for `commonMain`:

- Pure data models and queue identity types.
- Pure queue ordering / planning rules.
- Pure equalizer-curve and transition-planning calculations.
- Pure tests and serialization models where the dependencies support Kotlin/Native.

Do not move JVM-dependent code into `commonMain` unchanged. The existing 101-file `jvmSharedMain` layer includes Java/OkHttp/JSoup and other JVM assumptions. The network layer needs an abstraction and a platform engine (for example Ktor Darwin on Apple platforms and the appropriate engine on Android/JVM). InnerTube/NewPipe extraction dependencies need independent compatibility and service-terms review; simply changing the HTTP engine does not make them App Store-safe.

### Data, auth, and storage

- Use Keychain for credentials and refresh tokens.
- Use URLSession or a verified KMP networking layer for authorized APIs.
- Use SwiftData / Core Data or a carefully versioned local store for playlists, favorites, and listening history.
- Use `UIDocumentPickerViewController` only if local-file import is intentionally retained; iOS file access is permission-scoped and differs from Android MediaStore.
- Re-implement Android WebView/cookie-dependent login flows with supported iOS authentication sessions and each provider's documented OAuth flow.

### Native DSP and codec work

The current CMake tree contains JNI wrappers, Android logging, Oboe / AAudio-oriented exclusive output, USB-specific functionality, DSD / DST components, and analyzer / loop-mix renderers. Some platform-independent C/C++ algorithms may be reused, but every JNI wrapper must be replaced with an iOS bridge (Objective-C++ / Swift interoperability or Kotlin/Native interop as appropriate). Audio device access and exclusive USB output need separate iOS designs. Verify every included third-party license and notice before redistributing a combined iOS binary.

## Main release risks

### Third-party music service terms and App Review

This is the largest non-technical risk. The Android README describes YouTube Music catalogue discovery and playback, and the code contains YouTube / InnerTube stream resolution and download-related functionality. Apple's App Review Guidelines 5.2.2 require that apps using third-party services have permission under those services' terms. Guideline 5.2.3 says apps must not enable saving, converting, or downloading media from third-party sources such as YouTube without explicit authorization.

Therefore, a technically working iOS build is not the same as an App Store-approvable product. Before submitting, obtain the required service permissions or replace the affected source / download paths with an authorized provider. MusicKit is a potential Apple-native option for Apple Music catalog playback, subject to its own rules and any additional rights required for the planned integration. Do not treat MusicKit as permission to redistribute or download Apple Music files.

### Build and release environment

An iOS app must be built and signed through Apple's Xcode toolchain on macOS (locally or using a macOS CI runner). A Windows-only setup cannot run Xcode or iOS Simulator locally. Simulator CI can use code signing disabled; device builds, TestFlight, and App Store uploads require Apple signing and provisioning setup.

### Licensing

The repository documents the upstream BitChord codebase as GPL-3.0. The inspected `TransitionPlanner.kt` contains an explicit AGPL-3.0 notice, and native components include additional third-party notices/licenses (including LGPL-related material). Preserve original notices, verify compatibility and source-offer obligations for the exact files being carried over, and ship the corresponding source as required by applicable licenses. This audit is not a legal opinion.

## Scope estimate by engineering phase

| Phase | Scope | Exit condition |
|---|---|---|
| 0 — Product / rights decision | Choose an authorized catalog and define which Android-only features are deliberately omitted on iOS | Approved provider and feature list |
| 1 — iOS foundation | SwiftUI shell, navigation, theme, playback service, lock-screen metadata, background audio | Stable playback on a physical iPhone |
| 2 — Catalog | Search, track details, artwork, stream resolver adapter, error / retry states | Search and play from an authorized provider |
| 3 — Library | Guest/local playlists, favorites, queue, history, persistence | Data survives relaunch and upgrades |
| 4 — Lyrics / integrations | Timed lyrics, translation, supported account integrations, sync service | Provider-specific integration tests |
| 5 — Advanced audio | Crossfade, equalizer, audio analysis, AirPlay/Bluetooth route tests | DSP and route tests on supported devices |
| 6 — Distribution | Privacy disclosures, licenses, App Review compliance, TestFlight / App Store signing | TestFlight build and review-ready submission |

No reliable time estimate is included because the final scope depends heavily on the authorized catalog provider, which Android features are required on iOS, and access to a Mac / Apple Developer account.

## Audit boundary

This was a read-only source inspection of the GitHub repository tree and selected build, manifest, shared-module, native, README, workflow, and license-notice files. It was not a full dynamic security review, a complete line-by-line review of all 1,770 entries, or an iOS compile/test. The source repository was not modified.
