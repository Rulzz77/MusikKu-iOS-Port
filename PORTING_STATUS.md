# Porting status

Current state: **native iOS UI with Android-aligned Beranda / Explore / Koleksi navigation, global search, local collections, playback queue, lyrics tools and a Kotlin Multiplatform resolver. It is substantially closer to Android's core workflows, but it is not feature-equivalent or release-ready.**

## Implemented in the current development branch

- SwiftUI app with Beranda, Explore and Koleksi tabs; catalogue search opens globally from the main screens.
- Combined floating material dock with mini-player transport controls and tab navigation; dark BitChord palette with lavender accent, rounded artwork cards and horizontal music shelves.
- Explore mood/genre grid from FEmusic_moods_and_genres, category browse detail and artwork lookup.
- Home feed from FEmusic_home, with Home/Search/browse/category continuation paging.
- WEB_REMIX Search with All/Songs/Videos/Albums/Artists/Playlists filters, debounced query suggestions, local recent-search history with per-item deletion, and pagination.
- Album/artist/playlist browse pages with headers, artwork, related shelves, play-per-track/play-all and local collection actions.
- Persistent local playlists and favorites using versioned UserDefaults JSON keys; local data does not require login.
- Local listening history with play counts and AVPlayer elapsed listening time; totals are shown in the History tab. Individual entries can be deleted or the entire history cleared with confirmation. Pending progress is flushed when playback restarts, tracks change, or the app enters background.
- Play-count Mix and saved local Smart Playlist rules: minimum play count, optional artist filter, duration bounds, last-played window, ALL/ANY matching, and most-played/recently-played/most-listened sorting. Genre and release-year rules remain unavailable because the current iOS catalogue model does not expose those fields consistently.
- AVPlayer queue with enqueue/removal, clear-all with confirmation, next/previous, shuffle, repeat Off/All/One, automatic advance and manual drag-and-drop queue reordering.
- Now Playing screen and mini-player with artwork, seek, favorite, add-to-playlist, queue inspection and removal.
- Player settings with persistent 0.75×–2.0× playback speed, persisted repeat mode, sleep timer presets and custom 5-minute steps up to 12 hours, stop-after-current-track, and optional 30-second fade-out.
- MPNowPlayingInfoCenter / MPRemoteCommandCenter controls, audio-session interruption handling, headphone-removal pause and background audio configuration.
- Lyrics providers: automatic fallback or manual selection of lrc.red, BiniLyrics, BetterLyrics, BetterLyrics Portato and LRCLIB.
- On-demand lyric translation to Indonesian, English, Malay, Japanese, Korean, Simplified/Traditional Chinese, Spanish, French and German. Original line timestamps are preserved; translated lines use line-level rather than syllable karaoke timing.
- Persistent per-track local TTML import/export with line, word and syllable timestamps; imported files are size-limited to 5 MB and can be removed from the lyrics menu.
- Kotlin Multiplatform resolver-kmp module pinned to the same InnerTubeX v0.7.0 dependency used by Android.
- Ktor Darwin iOS transport; HTTPS direct-audio stream handoff to AVPlayer, persistent remote player-config cache, and per-request client playback nonce.
- Initial iOS WEB_BOTGUARD provider using a non-persistent WKWebView. Visitor/video-bound token values are memory-only; Google account cookies are not read or sent.
- GPL-3.0 license and third-party attribution notices copied into the derivative repository.

## Not integrated or not fully verified

- Live BotGuard challenge execution, visitor/video PoToken generation, attestation-gated stream extraction and audible playback have not yet been verified on a physical iPhone.
- Physical-device background playback, lock-screen interaction, Bluetooth/headset routing, interruptions and Wi-Fi/cellular handoff still need regression testing.
- Authenticated Google/YouTube account sessions, account/channel switching, account-backed likes and cloud-synced playlists are not implemented.
- Deeper nested browse parity and Android-specific remote recommendations remain incomplete.
- Additional Android catalogue/add-on sources, external playlist import and Listen Together/party sync are not ported.
- Smart Playlist genre/release-year matching is not available without reliable catalogue metadata.
- Download manager/offline audio are outside the current online-first iOS scope.
- Advanced DSP/equalizer/crossfade, specialised codecs, USB exclusive/bit-perfect audio and Android-specific device-routing behaviour are not ported.
- TestFlight/App Store signing and release regression testing remain outstanding.

## Validation

- GitHub Actions run #72 passed at commit 2d9b395: InnerTubeX iOS XCFramework build, XcodeGen generation, Simulator compile, Simulator install/launch, unsigned arm64 iPhone build, IPA packaging and artifact upload.
- Run #72's unsigned IPA is for that earlier source revision only. It does not include the later player, lyrics and Smart Playlist changes; use an artifact from a successful newer run when available.
- Latest source validation is running in GitHub Actions run #83 at commit f17b617. Its Simulator build/launch, unsigned iPhone IPA and artifact upload are not yet confirmed.
- The iOS Simulator smoke test only proves that the app installs and stays launched. It does not establish live BotGuard compatibility, PoToken generation, YouTube stream extraction or audible playback.
- QuickJS was upgraded to 1.0.18 with Kotlin Multiplatform 2.4.21 and Gradle 9.8.2; the prior QuickJS simulator linker warnings are gone. The remaining App Intents metadata-skip warning is expected because this app does not depend on AppIntents.framework.
- Physical-iPhone playback, background audio, audio routing and lock-screen tests remain outstanding.

Pull request: #1 — phase-1-ui-library-queue to main. The PR remains open and has not been merged.
