# MusikKu iOS — Porting Starter

This repository is a **separate iOS porting starter**, not a completed iOS conversion of the Android application.

It contains an XcodeGen-based SwiftUI shell, an AVPlayer playback foundation, lock-screen / Control Center command wiring, a macOS GitHub Actions simulator build, and the source audit / migration plan for the original repository.

## Relationship to the Android project

- Original project: https://github.com/Rulzz77/Musikku
- This starter does not modify the original repository.
- The current Android code is not copied wholesale into this starter. The audit identifies what can be shared and what needs a native iOS implementation.
- The catalog provider, login flows, lyrics providers, playlists, and advanced audio DSP are **not yet connected**. No unofficial music stream resolver or third-party credentials are bundled here.

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

## What works in this starter

- SwiftUI app entry point and a basic player shell.
- AVPlayer-based remote audio playback when a valid HTTPS stream URL is supplied by an authorized provider.
- Basic play/pause, seeking, periodic playback position, Now Playing metadata, and lock-screen / Control Center play-pause / skip commands.
- iOS background-audio mode declaration. Background operation still needs to be verified on a physical device after catalog playback is integrated.

## What is not implemented yet

- A real music catalog/search provider.
- Authentication, token refresh, or secure account storage.
- Playlist persistence / sync, favorites, listening history, and recommendations.
- Timed lyrics and translation providers.
- Queue management and next/previous track coordination.
- Advanced crossfade, equalizer, Automix, beat/vocal analysis, and lossless / DSD paths.
- Spotify import, Listen Together, or other third-party integrations.
- App Store/TestFlight signing and release pipeline.

See [the porting audit](docs/IOS_PORTING_AUDIT.md) and [feature migration matrix](docs/FEATURE_MIGRATION_MATRIX.md) before implementing those features.

## Suggested first milestone

1. Select a catalog / streaming provider whose terms expressly permit use in a third-party iOS app.
2. Implement search and a stable `Track` model adapter.
3. Connect authorized HTTPS playback URLs to `PlaybackManager`.
4. Verify interruption handling, Bluetooth, AirPlay, lock-screen controls, and background playback on a physical iPhone.
5. Add persistence and lyrics after playback is stable.

The project is deliberately conservative: it does not pretend the Android app's YouTube Music extraction or download paths are already iOS-compatible or App Store-approved.
