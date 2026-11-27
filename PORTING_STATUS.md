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

- [GitHub Actions run #153](https://github.com/Rulzz77/MusikKu-iOS-Port/actions/runs/46007785990) completed successfully at commit `402330e`: Simulator build and launch passed, **9 unit tests passed with 0 failures**, and all three artifacts (UI preview, Appetize Simulator ZIP, unsigned iPhone IPA) were uploaded.
- The 9 tests cover local playlist deduplication/persistence, Smart Playlist play-count/duration filtering, Indonesian error mapping (4 cases), and Spotify playlist URL parsing/host validation (3 cases).
- [Appetize Simulator artifact](https://github.com/Rulzz77/MusikKu-iOS-Port/actions/runs/46007785990/artifacts/15204360309): 4,444,120 bytes; expires 4 December 2026. This is the Simulator ZIP for Windows/Appetize testing.
- [Simulator UI preview](https://github.com/Rulzz77/MusikKu-iOS-Port/actions/runs/46007785990/artifacts/15203910710): 1,068,256 bytes; expires 4 December 2026. The preview showed the Home content bounded inside a centered panel, so a root-layout correction has since been committed and awaits new screenshot validation.
- [Unsigned IPA artifact](https://github.com/Rulzz77/MusikKu-iOS-Port/actions/runs/46007785990/artifacts/15203705838): 3,587,461 bytes; expires 4 December 2026. It is unsigned for personal Sideloadly testing, not a TestFlight or App Store release.
- Follow [Windows/Appetize testing instructions](docs/APPETIZE_WINDOWS_TESTING.md). The iOS Appetize simulator is useful for UI/flow checks but does not provide audible iOS audio output.
- The latest playback changes add an embedded player-config fallback, a last-resort AAC progressive MP4 path, and visible status/diagnostics. Those changes are **not yet covered by a completed full CI run**; the latest queued run must pass before considering them validated.
- AppIcon asset-catalog integration and a required-reason privacy manifest have been added; CI now lint-checks these assets. Their inclusion awaits validation by the next successful run.
- Simulator compilation, launch and IPA packaging do **not** establish live Webpage Attestation compatibility, PoToken generation, YouTube stream extraction, audible playback or physical-device audio behaviour.

Pull request: #1 — phase-1-ui-library-queue to main. The PR remains open and has not been merged. See [Release Readiness](docs/RELEASE_READINESS.md) for the remaining engineering, signing, privacy, licensing and content-rights gates.
