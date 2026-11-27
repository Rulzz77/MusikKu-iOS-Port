# MusikKu iOS — Native Port

This repository contains the separate native iOS project for MusikKu. It does not modify the Android repository at https://github.com/Rulzz77/Musikku.

## Current status

The native iOS port now follows Android's main navigation and several core workflows, but it is **not yet fully feature-equivalent or release-ready**.

Implemented in source on branch phase-1-ui-library-queue:

- SwiftUI tabs for Beranda, Explore and Koleksi, with global search and a floating translucent dock combining mini-player and navigation.
- Android-aligned dark palette, mood/genre Explore grid, category detail and Home feed shelves.
- WEB_REMIX catalog search with All/Songs/Videos/Albums/Artists/Playlists filters, debounced query suggestions, recent-search history and result pagination.
- Home feed, album/artist/playlist browse pages and category continuation paging.
- Local playlists, favorites, listening history, play counts, elapsed listening time, play-count Mix and Smart Playlist rules.
- Smart Playlist filters for minimum plays, optional artist, track-duration bounds and last-played window; ALL/ANY matching; sorting by most played, recently played or most listened. Genre/year rules await reliable catalogue metadata.
- AVPlayer queue with play-all, enqueue/remove, next/previous, shuffle, repeat Off/All/One, automatic advance and manual queue reordering; buffering-aware pause controls and fresh stream retry after AVPlayer item failure.
- Now Playing and mini-player with artwork, seeking, favorite, add-to-playlist, queue controls and lyrics.
- Player settings with persistent speed (0.75×–2.0×), repeat mode, sleep timer presets/custom durations up to 12 hours, stop-after-current-track and optional 30-second fade-out.
- Lock-screen / Control Center commands and audio-session interruption/headphone-removal handling.
- Lyrics providers with automatic fallback or manual source selection: lrc.red, BiniLyrics, BetterLyrics, BetterLyrics Portato and LRCLIB.
- On-demand lyrics translation to Indonesian, English, Malay, Japanese, Korean, Chinese, Spanish, French and German.
- Persistent per-track TTML import/export, retaining line/word/syllable timing where available.
- Kotlin Multiplatform InnerTubeX v0.13.2 resolver for the iOS target, Ktor Darwin 3.6.0, direct HTTPS stream handoff to AVPlayer and an anonymous Webpage Attestation provider using a non-persistent WKWebView. The Android repository is unchanged. After AVPlayer rejects a stream, that profile is excluded for 10 minutes and cipher refresh is scheduled in the background. Both Ktor Darwin sessions disable shared iOS cookie storage.

Local playlists, favorites, search history, listening stats and Smart Playlist rules do not require a login. There is no Google account/cloud sync yet. The Smart Playlist engine is still narrower than Android because genre and release-year metadata is not reliably available in the iOS catalogue model.

## Build and validation

GitHub Actions builds the InnerTubeX iOS XCFramework, generates the Xcode project, compiles for iOS Simulator, launches the app in an iPhone Simulator and exports an unsigned arm64 IPA for Sideloadly.

- [Run #136](https://github.com/Rulzz77/MusikKu-iOS-Port/actions/runs/45985450447) succeeded at commit `0a0df46`: InnerTubeX v0.13.2 XCFramework, XcodeGen, Simulator compile and launch, **5 unit tests (0 failures)**, unsigned arm64 iPhone IPA packaging and artifact upload.
- [Download the unsigned IPA artifact](https://github.com/Rulzz77/MusikKu-iOS-Port/actions/runs/45985450447/artifacts/15191644889) (3.58 MB; expires 4 December 2026).

- An unsigned IPA is for personal device testing with Sideloadly, not an App Store/TestFlight signed release.
- A build or Simulator launch does not verify live BotGuard challenge compatibility, PoToken generation, stream extraction or audible playback.

Actual YouTube playback, background audio, lock-screen controls and audio routing must be verified on a physical iPhone before release.

## Requirements for local build

- A Mac with Xcode installed (Xcode and iOS Simulator require Apple's toolchain).
- Homebrew, Java 21, Gradle 9.8.2 and XcodeGen.
- For App Store/TestFlight distribution: Apple Developer signing, provisioning and App Store Connect setup.

Install XcodeGen:

~~~bash
brew install xcodegen
~~~

Build the Kotlin Multiplatform resolver framework and generate the iOS project:

~~~bash
gradle --no-daemon :resolver-kmp:assembleMusikKuResolverKitReleaseXCFramework
xcodegen generate --spec ios/project.yml --project ios
~~~

Build for Simulator:

~~~bash
xcodebuild -project ios/MusikKu.xcodeproj \\
  -scheme MusikKu \\
  -sdk iphonesimulator \\
  -destination 'generic/platform=iOS Simulator' \\
  CODE_SIGNING_ALLOWED=NO build
~~~

Open the generated project in Xcode:

~~~bash
open ios/MusikKu.xcodeproj
~~~

## Important limitations

- Catalog metadata and stream extraction depend on third-party services whose protocols and availability may change.
- Background audio is declared and AVAudioSession is configured, but physical iPhone, Bluetooth and lock-screen tests are still required.
- Playlists, favorites, history and Smart Playlist rules are stored locally on this device only; there is no cloud account sync.
- Offline download is not part of the current online-first iOS scope.
- Advanced DSP/equalizer/crossfade, specialised codecs, USB exclusive/bit-perfect audio, extra Android add-on sources and party sync are not ported.
- A technical build does not establish third-party service permission or App Store approval.

See the porting audit, feature migration matrix and porting status for implementation details and remaining work.

The iOS repository carries the upstream GPL-3.0 license and third-party attribution from the Android MusikKu source; see LICENSE and THIRD_PARTY_NOTICES.md. Review all license and distribution obligations before publishing an iOS binary.
