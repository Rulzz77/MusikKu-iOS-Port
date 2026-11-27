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

The search screen intentionally shows that the catalog is not connected yet. No production catalog, stream resolver, account provider, or lyric provider is included at this stage.

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

- The catalog and online search are not connected.
- Playback requires a valid HTTP(S) stream URL provided by a source authorized for use in this app.
- Background audio is declared and the AVAudioSession is configured, but it still needs physical-iPhone verification.
- Local playlists and favorites are stored on the current device only; no login or cloud sync is implemented.
- The project does not currently provide APK-style self-updates. iOS distribution uses TestFlight / App Store channels.
- A technically successful build does not by itself establish third-party service permission or App Store approval.

See [the porting audit](docs/IOS_PORTING_AUDIT.md), [feature migration matrix](docs/FEATURE_MIGRATION_MATRIX.md), and [porting status](PORTING_STATUS.md) for details.
