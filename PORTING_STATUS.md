# Porting status

Current state: **native iOS UI with Android-aligned Home/Explore/Library navigation, global search, floating player dock, mood/genre browsing, local listening history and a play-count-based Mix. It is still not feature-equivalent to Android.**

Implemented in the current development branch:
- SwiftUI app with Android-aligned Beranda, Explore, and Koleksi tabs; catalogue search is opened globally from the main screens.
- Combined floating material dock with mini-player transport controls and main-tab navigation.
- Android-aligned dark palette and mood/genre Explore grid sourced from `FEmusic_moods_and_genres`.
- Local listening history with play counts, elapsed listening time, totals in the History tab, and flushing of pending progress when switching tracks or entering background; Mix queue ranked by frequently played tracks.
- Saved local Smart Playlist rules with minimum play count, optional artist filter, track-duration bounds, last-played window, ALL/ANY matching and most-played/recently-played/most-listened ordering.
- Persistent local playlists and favorites using versioned UserDefaults JSON keys.
- Playlist detail can queue tracks and remove items when a track has a resolved stream.
- AVPlayer queue foundation: play a queue, enqueue, remove a queue item, next, previous, shuffle, repeat-one, and automatic advance.
- Mini-player and full Now Playing screen with artwork, seek, favorite, add-to-playlist, queue inspection/removal, and manual queue reordering.
- Lock-screen / Control Center play, pause, next, previous, seek, and asynchronously loaded artwork.
- Audio interruption and headphone-removal pause handling.
- Read-only YouTube Music search using the Android repository's anonymous WEB_REMIX request pattern, client identity, and filter parameters.
- Search continuation paging, local recent-search history, debounced YouTube Music query suggestions, Home-feed continuation paging, and album/playlist/category browse continuation paging.
- Listening counts are recorded when AVPlayer actually starts a resolved stream, rather than when a track is merely selected.
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
- Deeper nested browse parity, continuation for shelves inside complex artist pages, and continuation edge-case compatibility still need live-response testing.
- Other Android catalogue/add-on sources such as JioSaavn and custom modules.
- Persistent per-track local TTML import/export; selectable automatic, lrc.red, BiniLyrics, BetterLyrics, BetterLyrics Portato and LRCLIB providers; on-demand lyric translation to Indonesian, English, Malay, Japanese, Korean, Chinese, Spanish, French and German (line timing preserved).
- Download manager, offline audio, remote recommendations, remaining Smart Playlist metadata filters (genre and release-year are not yet available in the iOS track catalogue), and cross-device sync.
- Native DSP, equalizer, crossfade, advanced codecs, USB audio, and specialized device-routing parity.
- TestFlight or App Store release signing.

The resolver uses InnerTubeX `v0.7.0`, matching Android's pinned dependency. It requests direct audio transport because AVPlayer cannot consume the Android/SABR segmented path directly. The iOS PoToken provider uses an isolated non-persistent WebKit data store and does not use Google account cookies. The provider is a best-effort technical integration, not a guarantee that every YouTube item will be playable.

Validation:
- GitHub Actions passed at commit `b0a5aebd5c2e2dcc5542044c4b6c7dfd1acd87f9`: InnerTubeX iOS XCFramework build, XcodeGen project generation, iOS Simulator compile, and an install/launch smoke test on an available iPhone Simulator.
- The smoke test installed bundle `id.musikku.ios`, launched the app, and confirmed its process remained alive for the 10-second check.
- QuickJS was upgraded to `1.0.18` (with Kotlin Multiplatform `2.4.21` and Gradle `9.8.2`). The earlier QuickJS simulator linker warnings are gone; the remaining App Intents metadata-skip warning is expected because this app does not depend on `AppIntents.framework`.
- CI install/launch validation does not verify live BotGuard challenge compatibility, PoToken generation, YouTube stream extraction, or audible playback. Those still require runtime testing with a real playback request.
- Physical-iPhone playback, background audio, audio routing, and lock-screen tests remain outstanding.


Pull request: [#1 — phase-1-ui-library-queue → main](https://github.com/Rulzz77/MusikKu-iOS-Port/pull/1). The PR remains open for further testing and review.
