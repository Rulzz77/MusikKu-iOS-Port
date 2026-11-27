# MusikKu iOS — Native Port

This repository is the separate native iOS project for MusikKu. It does not modify the Android repository at https://github.com/Rulzz77/Musikku.

## Current status

The project is an actively developed iOS port, not yet a complete feature-equivalent release. The current development branch contains:

- SwiftUI tabs: Beranda, Cari, and Koleksi.
- Local playlist creation, deletion, track removal, and favorites.
- Playback from local playlist/favorite entries once they contain a valid authorized stream URL.
- An AVPlayer queue foundation with enqueue, removal, next/previous, shuffle, repeat-one, and automatic advance.
- A mini-player and full Now Playing screen with artwork, seeking, favorite, playlist, and queue controls.
- Lock-screen / Control Center transport commands and audio-interruption handling.
- Read-only YouTube Music catalog search and the first Home feed shelves using the same anonymous WEB_REMIX request shape as the Android project.
- Search filters for all, songs, videos, albums, artists, and playlists.
- Save catalog song/video metadata to the local favorites library.
- Home shelf cards with artwork, titles, and artist/subtitle metadata.
- Read-only browse detail sheets for album, artist, and playlist search results, including the page header, first track list, and related shelves.

Home, Search, and the first browse detail screens retrieve catalogue metadata and artwork. They do not yet resolve playable audio URLs, expose account/library writes, or page through continuation results. The iOS stream resolver and the Android-specific InnerTubeX / PoToken path still need a native iOS implementation.

## Requirements

- A Mac with Xcode installed (iOS builds and Simulator require Apple's toolchain).
- Homebrew and XcodeGen.
- For device/TestFlight distribution: Apple Developer signing, provisioning, and App Store Connect setup.

Install XcodeGen:

```bash
brew install xcodegen
```

Generate and build the iOS Simulator app:

```bash
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
- Search results are metadata only until a native, authorized stream resolver supplies a valid HTTP(S) URL to AVPlayer.
- Background audio is declared and the AVAudioSession is configured, but it still needs physical-iPhone verification.
- Local playlists and favorites are stored on the current device only; no login or cloud sync is implemented.
- The project does not currently provide APK-style self-updates. iOS distribution uses TestFlight / App Store channels.
- A technically successful build does not by itself establish third-party service permission or App Store approval.

The iOS repository carries the upstream GPL-3.0 license and third-party attribution from the Android MusikKu source; see [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Check the license and distribution requirements before publishing an iOS binary.

See [the porting audit](docs/IOS_PORTING_AUDIT.md), [feature migration matrix](docs/FEATURE_MIGRATION_MATRIX.md), and [porting status](PORTING_STATUS.md) for details.
