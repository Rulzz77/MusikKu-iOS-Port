# Porting status

Current state: **native iOS UI with Android-aligned Beranda / Explore / Koleksi navigation, global search, local collections, playback queue, lyrics tools and a Kotlin Multiplatform resolver. It is substantially closer to Android's core workflows, but it is not feature-equivalent or release-ready.**

## Implemented in the current development branch

- SwiftUI app with Beranda, Explore and Koleksi tabs; catalogue search opens globally from the main screens.
- Combined floating material dock with mini-player transport controls and tab navigation; dark BitChord palette with lavender accent, rounded artwork cards and horizontal music shelves.
- Explore mood/genre grid from FEmusic_moods_and_genres, category browse detail and artwork lookup.
- Home feed from FEmusic_home, with Home/Search/browse/category continuation paging.
- WEB_REMIX Search with All/Songs/Videos/Albums/Artists/Playlists filters, debounced query suggestions, local recent-search history with per-item deletion, and pagination.
- Album/artist/playlist browse pages with headers, artwork, related shelves, play-per-track/play-all, local collection actions and add-to-queue actions from catalog rows/cards.
- Persistent local playlists and favorites using versioned UserDefaults JSON keys; local data does not require login.
- Public Spotify playlist URL import without Spotify or Google login; source rows are matched conservatively against song title, primary artist and duration, and only unique safe matches are saved as a local playlist. Unmatched rows, lookup failures and rows missing title metadata are preserved in source order and can be manually matched to a chosen catalogue track. Imports are rejected when the reported playlist total exceeds the embed rows returned, preventing silent partial imports.
- Local listening history with play counts and AVPlayer elapsed listening time; totals are shown in the History tab. Individual entries can be deleted or the entire history cleared with confirmation. Pending progress is flushed when playback restarts, tracks change, playback pauses/interruption occurs, or the app enters background.
- Play-count Mix and saved local Smart Playlist rules: minimum play count, optional artist filter, duration bounds, last-played window, ALL/ANY matching, and most-played/recently-played/most-listened sorting. Genre and release-year rules remain unavailable because the current iOS catalogue model does not expose those fields consistently.
- AVPlayer queue with enqueue/removal from Search/Home/Explore, clear-all with confirmation, next/previous, shuffle, repeat Off/All/One, automatic advance and manual drag-and-drop queue reordering. Buffering-aware pause controls are consistent across the dock, mini-player and full player; a failed AVPlayer item can be retried with a fresh resolution.
- Now Playing screen and mini-player with artwork, seek, favorite, add-to-playlist, queue inspection and removal.
- Player settings with persistent 0.75×–2.0× playback speed, persisted repeat mode, sleep timer presets and custom 5-minute steps up to 12 hours, stop-after-current-track, and optional 30-second fade-out.
- MPNowPlayingInfoCenter / MPRemoteCommandCenter controls, audio-session interruption handling, headphone-removal pause and background audio configuration.
- Lyrics providers: automatic fallback or manual selection of lrc.red, BiniLyrics, BetterLyrics, BetterLyrics Portato and LRCLIB.
- On-demand lyric translation to Indonesian, English, Malay, Japanese, Korean, Simplified/Traditional Chinese, Spanish, French and German. Original line timestamps are preserved; translated lines use line-level rather than syllable karaoke timing.
- Persistent per-track local TTML import/export with line, word and syllable timestamps; imported files are size-limited to 5 MB and can be removed from the lyrics menu.
- Kotlin Multiplatform resolver-kmp now consumes InnerTubeX v0.13.2 for iOS; the Android repository remains untouched. The library supplies its current player-config/cipher and stream-selection pipeline. Profiles rejected by AVPlayer are excluded per video for 10 minutes using a monotonic clock, and cipher refresh is scheduled asynchronously after rejection.
- Ktor Darwin 3.6.0 iOS transport with shared cookie storage disabled for both resolver and token HTTP sessions; HTTPS direct-audio handoff to AVPlayer, persistent remote player-config cache, and a per-request client playback nonce.
- iOS WEBPAGE_ATTESTATION provider: watch-page challenge parsing, trusted HTTPS interpreter validation, and GenerateIT exchange run with a non-persistent WKWebView. The provider rejects authenticated cookies, sends only a static consent preference, and keeps visitor/video-bound token values in memory only.
- GPL-3.0 license and third-party attribution notices copied into the derivative repository.

## Not integrated or not fully verified

- The Webpage Attestation provider compiles and its framework packages successfully, but live YouTube challenge execution, visitor/video PoToken generation, attestation-gated stream extraction, and audible playback have not yet been verified on a physical iPhone.
- Physical-device background playback, lock-screen interaction, Bluetooth/headset routing, interruptions and Wi-Fi/cellular handoff still need regression testing.
- Authenticated Google/YouTube account sessions, account/channel switching, account-backed likes and cloud-synced playlists are not implemented.
- Deeper nested browse parity and Android-specific remote recommendations remain incomplete.
- Other external playlist providers and Android add-on/catalogue sources are not ported. Spotify import currently reads public embed playlists only; it rejects incomplete embed results at the 100-row boundary and supports manual replacement search for unmatched or failed rows.
- Smart Playlist genre/release-year matching is not available without reliable catalogue metadata.
- Download manager/offline audio are outside the current online-first iOS scope.
- Advanced DSP/equalizer/crossfade, specialised codecs, USB exclusive/bit-perfect audio and Android-specific device-routing behaviour are not ported.
- TestFlight/App Store signing and release regression testing remain outstanding.

## Validation

- [GitHub Actions run #142](https://github.com/Rulzz77/MusikKu-iOS-Port/actions/runs/45999374004) passed at commit `242a8e8`: all 14 workflow steps completed successfully, including InnerTubeX XCFramework build, XcodeGen generation, Simulator compilation, **5 unit tests with 0 failures**, Simulator install/launch smoke test, Appetize Simulator ZIP packaging/upload and unsigned arm64 iPhone IPA packaging.
- [Appetize Simulator artifact](https://github.com/Rulzz77/MusikKu-iOS-Port/actions/runs/45999374004/artifacts/15198806531): 4,429,251 bytes; SHA-256 `bcd67f767b62131d408c28fa702d80803f96c0fbc81667a0dbcbd77f8bb47ac9`; expires 4 December 2026. This contains the iOS Simulator build intended for Appetize browser testing from Windows. Follow [Windows/Appetize testing instructions](docs/APPETIZE_WINDOWS_TESTING.md).
- [Unsigned IPA artifact](https://github.com/Rulzz77/MusikKu-iOS-Port/actions/runs/45999374004/artifacts/15199215916): 3,574,894 bytes; SHA-256 `0dd644390e2b1b5d95684e96f3c65c0d3554620feef54a0c47109f586f11d50f`; expires 4 December 2026. It is unsigned for personal Sideloadly testing, not a TestFlight or App Store release.
- The CI suite covers public Spotify playlist URL parsing (3 cases), local playlist deduplication/persistence (1 case), and Smart Playlist play-count/duration filtering (1 case).
- Simulator compilation, launch and IPA packaging verify build viability only. They do **not** establish live Webpage Attestation compatibility, PoToken generation, YouTube stream extraction, audible playback or physical-device audio behaviour.
- Xcode still emits non-fatal validation warnings for supported orientations and launch configuration during the physical-device IPA packaging step; investigate before release.
- Physical-iPhone validation remains outstanding: audible stream playback, screen-locked background playback, lock-screen/Control Center, interruptions, Bluetooth/headset routing and Wi-Fi/cellular handoff.

Pull request: #1 — phase-1-ui-library-queue to main. The PR remains open and has not been merged.
