# Porting status

Current state: **native iOS UI, local library, catalogue Home/Search/browse, lyrics, direct-audio resolver, and an initial WKWebView BotGuard provider — not yet feature-equivalent to Android.**

Implemented in the current development branch:
- SwiftUI app with Beranda, Cari, and Koleksi tabs.
- Persistent local playlists and favorites using versioned UserDefaults JSON keys.
- Playlist detail can queue tracks and remove items when a track has a resolved stream.
- AVPlayer queue foundation: play a queue, enqueue, remove a queue item, next, previous, shuffle, repeat-one, and automatic advance.
- Mini-player and full Now Playing screen with artwork, seek, favorite, add-to-playlist, and queue inspection/removal.
- Lock-screen / Control Center play, pause, next, previous, seek, and asynchronously loaded artwork.
- Audio interruption and headphone-removal pause handling.
- Read-only YouTube Music search using the Android repository's anonymous WEB_REMIX request pattern, client identity, and filter parameters.
- Search filters for all, songs, videos, albums, artists, and playlists.
- First-page Home feed from `FEmusic_home`, plus album/artist/playlist browse details and local collection actions.
- Lyrics providers: lrc.red, BiniLyrics, BetterLyrics, BetterLyrics Portato, and LRCLIB fallback; TTML supports line, word, and syllable timing.
- Kotlin Multiplatform `resolver-kmp` module pinned to the same InnerTubeX `v0.7.0` dependency used by Android MusikKu.
- iOS Darwin HTTP transport with audio-only extraction (`HLS` and `SABR` disabled) and AVPlayer handoff of direct HTTPS URL plus request headers.
- Persistent iOS `NSUserDefaults` cache for InnerTubeX remote player configs, matching the Android player-config source and refresh behavior.
- Client playback nonce generation for each stream extraction request.
- Initial iOS BotGuard provider using a non-persistent WKWebView for JavaScript execution and Ktor Darwin for fixed HTTPS BotGuard requests.
- Visitor-bound streaming PoToken caching and video-ID-bound player PoToken generation in memory; no Google account cookies are read or attached.
- Best-effort resolver prewarm at player initialization to load player config, cipher support, and (when available) attestation before the first play tap.
- UI state for stream-resolution progress and resolver errors.
- Catalog playback controls now hand songs/videos from Search and Home shelves into the AVPlayer queue; browse pages provide play-per-track and play-all actions.
- Upstream GPL-3.0 license and third-party notices copied into this derivative repository.

Still not integrated or not fully verified:
- WKWebView BotGuard initialization and token-provider code compile successfully in iOS CI. Live challenge execution, PoToken generation, attestation-gated stream extraction, and audible playback still require runtime verification; YouTube can change its challenge protocol.
- Authenticated Google/YouTube account sessions, account/channel switching, account likes, and server-synced playlists.
- Home/search/browse continuation paging, richer catalogue detail parity, and nested browse navigation.
- Other Android catalogue/add-on sources such as JioSaavn and custom modules.
- Lyrics translation, local TTML import/export, provider settings, and more Android lyric-source parity.
- Download manager, offline audio, listening history, recommendations, smart playlists, and cross-device sync.
- Native DSP, equalizer, crossfade, advanced codecs, USB audio, and specialized device-routing parity.
- TestFlight or App Store release signing.

The resolver uses InnerTubeX `v0.7.0`, matching Android's pinned dependency. It requests direct audio transport because AVPlayer cannot consume the Android/SABR segmented path directly. The iOS PoToken provider uses an isolated non-persistent WebKit data store and does not use Google account cookies. The provider is a best-effort technical integration, not a guarantee that every YouTube item will be playable.

Validation:
- GitHub Actions iOS Simulator build passed at commit `624ffe1` (`624ffe1379fb5f17c19a9a77e3b680af34e3afc2`). All three core steps passed: InnerTubeX iOS XCFramework build, XcodeGen project generation, and iOS Simulator compile.
- The passing CI includes the WKWebView BotGuard provider, Ktor Darwin request path, non-persistent WebKit data store, and the recent token-result cleanup.
- CI compilation does not execute the app or verify live BotGuard challenge compatibility, PoToken generation, YouTube stream extraction, or audible playback. End-to-end playback still needs runtime and physical-device testing.
- Physical-iPhone playback, background audio, audio routing, and lock-screen tests remain outstanding.


Pull request: [#1 — phase-1-ui-library-queue → main](https://github.com/Rulzz77/MusikKu-iOS-Port/pull/1). The PR remains open for further testing and review.
