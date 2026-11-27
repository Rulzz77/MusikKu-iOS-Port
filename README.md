# MusikKu iOS — Native Port

This repository is the separate native iOS project for MusikKu. It does not modify the Android repository at https://github.com/Rulzz77/Musikku.

## Current status

The project is an actively developed iOS port, not yet a complete feature-equivalent release. The current development branch contains:

- SwiftUI tabs: Beranda, Cari, and Koleksi.
- Local playlist creation, deletion, track removal, and favorites.
- Catalog song/video Play actions from Search, Home shelves, and browse pages, connected to the AVPlayer queue and InnerTubeX stream resolver.
- Play-all for tracks exposed by album/artist/playlist browse pages.
- An AVPlayer queue foundation with enqueue, removal, next/previous, shuffle, repeat-one, and automatic advance.
- A Kotlin Multiplatform audio resolver using the same InnerTubeX `v0.7.0` dependency as Android MusikKu, with Ktor Darwin for iOS.
- A mini-player and full Now Playing screen with artwork, seeking, favorite, playlist, and queue controls.
- Lock-screen / Control Center transport commands and audio-interruption handling.
- Read-only YouTube Music catalog search and the first Home feed shelves using the same anonymous WEB_REMIX request shape as the Android project.
- Search filters for all, songs, videos, albums, artists, and playlists.
- Save catalog song/video metadata to the local favorites library.
- Home shelf cards with artwork, titles, and artist/subtitle metadata.
- Read-only browse detail sheets for album, artist, and playlist items from Search and Home, including the page header, first track list, and related shelves.
- Add catalogue tracks from browse details to local playlists or favorites.
- Initial iOS WEB_BOTGUARD token-provider integration using an isolated, non-persistent WKWebView and Ktor Darwin. It caches visitor-bound streaming tokens in memory and generates video-ID-bound player tokens without reading or attaching Google account cookies.

Home, Search, and browse details retrieve catalogue metadata and artwork. Selecting Play hands a YouTube song/video ID to the KMP resolver, which attempts to extract a direct HTTPS audio URL and passes the required request headers to AVPlayer. Remote player config is cached on iOS and each extraction uses a client playback nonce. GitHub Actions passed the Kotlin/Native XCFramework build, XcodeGen project generation, and iOS Simulator compile at commit `b0a5aeb`. The workflow also installed MusikKu in an iPhone Simulator and confirmed that the app process remained alive during a 10-second launch smoke test. QuickJS `1.0.18` with Kotlin Multiplatform `2.4.21` and Gradle `9.8.2` removed the previous QuickJS simulator linker warnings. The only remaining build warning is the expected App Intents metadata skip because this app does not use `AppIntents.framework`. The smoke test verifies install and startup only; live WKWebView challenge execution, PoToken minting, stream extraction, and audible playback still require runtime testing on a physical iPhone. The provider does not read or attach Google account cookies.

## Requirements

- A Mac with Xcode installed (iOS builds and Simulator require Apple's toolchain).
- Homebrew, Gradle 9.8.2 or newer, Java 21, and XcodeGen.
- For device/TestFlight distribution: Apple Developer signing, provisioning, and App Store Connect setup.

Install XcodeGen:

```bash
brew install gradle xcodegen
```

Build the Kotlin Multiplatform resolver framework, then generate and build the iOS Simulator app:

```bash
gradle --no-daemon :resolver-kmp:assembleMusikKuResolverKitReleaseXCFramework
xcodegen generate --spec ios/project.yml --project ios
xcodebuild -project ios/MusikKu.xcodeproj \
  -scheme MusikKu \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

Open the generated project in Xcode:

```bash
open ios/MusikKu.xcodeproj
```

## Important limitations

- Search is connected to the Android project's anonymous WEB_REMIX catalogue request shape, but service availability and response changes are controlled by the third-party endpoint.
- Search/Home Play actions are wired to InnerTubeX and AVPlayer. The resolver and app compile in CI, and the app installs and launches in iOS Simulator; live BotGuard challenge compatibility, token generation, stream extraction, and audible playback on a physical iPhone remain unverified.
- Background audio is declared and the AVAudioSession is configured, but it still needs physical-iPhone verification.
- Local playlists and favorites are stored on the current device only; no login or cloud sync is implemented.
- The project does not currently provide APK-style self-updates. iOS distribution uses TestFlight / App Store channels.
- A technically successful build does not by itself establish third-party service permission or App Store approval.

The iOS repository carries the upstream GPL-3.0 license and third-party attribution from the Android MusikKu source; see [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Check the license and distribution requirements before publishing an iOS binary.

See [the porting audit](docs/IOS_PORTING_AUDIT.md), [feature migration matrix](docs/FEATURE_MIGRATION_MATRIX.md), and [porting status](PORTING_STATUS.md) for details.
