# MusikKu iOS — Native Port

This repository contains the separate native iOS project for MusikKu. It does not modify the Android repository at https://github.com/Rulzz77/Musikku.

## Current status

The iOS branch now follows Android's main navigation and several core workflows, but it is **not yet feature-equivalent or release-ready**.

Implemented in source on branch `phase-1-ui-library-queue`:

- SwiftUI tabs for Beranda, Explore, and Koleksi, with global search and a floating translucent mini-player/navigation dock.
- Android-aligned dark palette, mood/genre Explore grid, category detail and Home feed shelves.
- WEB_REMIX catalog search with all/song/video/album/artist/playlist filters, debounced query suggestions, recent-search history and result pagination.
- Home feed continuation, album/artist/playlist browse details and browse/category continuation.
- Local playlists, favorites, listening history, play counts, play-count-based Mix and local Smart Playlist rules.
- AVPlayer queue with play-all, enqueue/remove, next/previous, shuffle, repeat-one, automatic advance and manual queue reordering.
- Mini-player, full Now Playing sheet, artwork, seeking, favorite, add-to-playlist, queue and lyrics sheets.
- Lock-screen / Control Center commands and audio-session interruption/headphone-removal handling.
- Lyrics providers: lrc.red, BiniLyrics, BetterLyrics, BetterLyrics Portato and LRCLIB fallback; TTML line/word/syllable timing.
- Kotlin Multiplatform resolver using the same InnerTubeX v0.7.0 dependency as Android, Ktor Darwin and an initial non-persistent WKWebView BotGuard token provider.

The local Smart Playlist implementation is intentionally narrower than Android: it currently supports a minimum play count, optional artist filter and most-played/recently-played sorting. The full Android rules engine, additional provider/add-on sources, external playlist imports, advanced DSP, party sync and account/cloud functionality are not yet ported.

## Build and validation

GitHub Actions builds the InnerTubeX iOS XCFramework, generates the Xcode project, compiles for the iOS Simulator, launches the app in an iPhone Simulator and exports an unsigned arm64 IPA artifact for Sideloadly. A previously successful run created an IPA for an earlier commit; each newer source commit must pass its own workflow before its artifact is used.

The unsigned IPA is intended for personal device testing with Sideloadly. It is **not** an App Store/TestFlight signed release. Signing and installation on a physical iPhone do not prove that live YouTube playback works.

Latest code changes still require CI validation. Live BotGuard challenge execution, visitor/video PoToken generation, real stream extraction, audible playback, background audio, lock-screen behaviour and audio routing must be verified on a physical iPhone.

## Requirements for local build

- A Mac with Xcode installed (Xcode and iOS Simulator require Apple's toolchain).
- Homebrew, Java 21, Gradle 9.8.2 and XcodeGen.
- For App Store/TestFlight distribution: Apple Developer signing, provisioning and App Store Connect setup.

Install XcodeGen:

```bash
brew install xcodegen
```

Build the Kotlin Multiplatform resolver framework and generate the iOS project:

```bash
gradle --no-daemon :resolver-kmp:assembleMusikKuResolverKitReleaseXCFramework
xcodegen generate --spec ios/project.yml --project ios
```

Build for Simulator:

```bash
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

- Catalog metadata and stream extraction depend on third-party services whose protocols and availability may change.
- A successful build or simulator launch does not prove live BotGuard compatibility, stream extraction or audible playback.
- Background audio is declared and AVAudioSession is configured, but physical iPhone, Bluetooth and lock-screen tests are still required.
- Playlists, favorites, history and Smart Playlist rules are stored on this device only. No cloud account sync is included.
- The app is online-first; offline download functionality is not part of the current iOS scope.
- A technical build does not establish third-party service permission or App Store approval.

See [the porting audit](docs/IOS_PORTING_AUDIT.md), [feature migration matrix](docs/FEATURE_MIGRATION_MATRIX.md) and [porting status](PORTING_STATUS.md) for implementation details and remaining work.

The iOS repository carries the upstream GPL-3.0 license and third-party attribution from the Android MusikKu source; see [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Review all license and distribution obligations before publishing an iOS binary.