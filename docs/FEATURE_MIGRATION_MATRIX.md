# Feature Migration Matrix

This matrix distinguishes source implementation from runtime validation. A native iOS screen or successful Simulator build does not prove that a remote provider, BotGuard challenge, audio stream or physical-device audio route works.

| Android MusikKu capability | iOS implementation | Status |
|---|---|---|
| Main navigation | SwiftUI Beranda / Explore / Koleksi; global Search sheet; floating material dock with mini-player | Build #136 compiled, installed and launched in Simulator; 5 automated tests passed |
| Android visual language | Dark BitChord palette, lavender accent, rounded cards, artwork shelves and translucent dock | Adapted to SwiftUI; pixel-identical parity is not intended |
| Home feed | WEB_REMIX FEmusic_home, artwork shelves, recent plays, play-count Mix and continuation paging | Implemented in source; live response/pagination needs device testing |
| Explore / mood / genre | FEmusic_moods_and_genres, category grid, browse detail and category continuation paging | Implemented in source; parser depends on live third-party response format |
| Search | WEB_REMIX filters, query suggestions, local recent-search list and result continuation paging | Implemented in source; live suggestions/continuations need runtime validation |
| Album / artist / playlist pages | Header/artwork, tracks, related shelves, play-all, save/favorite and continuation paging | Implemented in source; deeper nested browse parity remains incomplete |
| Local playlists / favorites | Create/delete local playlists, add/remove tracks and favorites | Implemented with local UserDefaults persistence; no account required |
| Spotify playlist import | Public Spotify embed metadata, strict title/primary-artist/duration matching, save matches as a local playlist | Implemented without login; missing-title rows are preserved as manual-review entries; partial embed payloads are rejected when the reported total is higher; manual replacement is available |
| Listening history / statistics | Play counts, last-played time, AVPlayer elapsed listening time and History totals | Implemented in source; stored locally on this device |
| Mix / Smart Playlists | Minimum plays, optional artist, duration bounds, last-played window, ALL/ANY matching, most-played/recent/most-listened sorting | Substantial local subset implemented; genre/release-year metadata filters remain unavailable |
| Player / queue | AVPlayer queue, enqueue/remove, next/previous, shuffle, repeat Off/All/One, auto advance, manual reordering, buffering-aware pause and fresh-resolution retry after AVPlayer item failure | Implemented in source; playback reliability requires physical-device verification |
| Player settings | Persistent 0.75×–2.0× speed and repeat; sleep timer presets/custom up to 12 hours, stop-after-track and 30-second fade | Implemented in source; timer/audio behaviour requires device testing |
| Now Playing | Artwork, seek, favorite, add-to-playlist, lyrics and queue sheets, mini-player | Implemented in source; further Android player customisation remains |
| Lock screen / Control Center | MPNowPlayingInfoCenter, MPRemoteCommandCenter, artwork, transport and seek | Implemented in source; verify on a physical iPhone |
| Background audio / interruptions | AVAudioSession playback, background audio mode, interruption/headphone handling | Configured in source; physical-device/Bluetooth tests pending |
| Lyrics | Automatic or manual provider: lrc.red, BiniLyrics, BetterLyrics, BetterLyrics Portato, LRCLIB; TTML line/word/syllable timing; translation and persistent per-track TTML import/export | Implemented in source; third-party services and file round-trip need runtime testing |
| Resolver / YouTube stream | KMP InnerTubeX v0.13.2 for iOS, Ktor Darwin 3.6.0, HTTPS audio handoff, Webpage Attestation via isolated WKWebView, embedded-config fallback, 10-minute per-video profile exclusion and asynchronous cipher refresh after AVPlayer refusal | Framework compiles and packages in CI; live challenge, PoToken generation, stream extraction and audible playback remain unverified on a physical iPhone |
| Guest-first usage | Local playlists/favorites/history/Smart Mix do not require login | Implemented for local data; no cloud sync |
| Google / YouTube account, remote likes | Approved OAuth, account/channel switching and account-backed library | Not implemented |
| Additional Android sources / add-ons | Separate provider adapters and source-specific terms/permissions | Not implemented |
| External playlist import | Public Spotify playlist URL import only; other providers and account-backed imports remain out of scope | Partial; public playlists only, manual replacement is available, but there is no complete pagination beyond Spotify's public embed payload |
| Offline downloads | Online-first catalog playback | Not in current iOS scope |
| Full Android DSP / equalizer / crossfade | Native audio processing and AVPlayer/AVAudioEngine integration | Not implemented |
| Listen Together / party sync | New native iOS client and protocol testing | Not implemented |
| USB exclusive / bit-perfect / advanced codecs | Reassess against iOS audio-session and accessory APIs | Not implemented; no parity claim |
| Android APK updater | TestFlight / App Store distribution | Not applicable on iOS |
| Release signing | Apple signing, provisioning and App Store Connect | Not configured; current artifact is unsigned for Sideloadly testing |

## Resolver architecture

The iOS target consumes a Kotlin Multiplatform framework built from resolver-kmp and pins InnerTubeX v0.13.2 for the iOS target only; the Android repository is not modified by this port. Ktor Darwin 3.6.0 requests direct audio streams with HLS/SABR disabled before passing the HTTPS URL and required headers to AVPlayer. InnerTubeX provides its current embedded player-config/cipher fallback and client-selection pipeline. When AVPlayer rejects a stream, the resolver records the exact profile ID, excludes it for that video for up to 10 minutes using monotonic time, and schedules a cipher-config refresh asynchronously. Both the main resolver HTTP client and the token HTTP client disable shared iOS cookie storage. Webpage Attestation parses the watch-page challenge, validates the HTTPS interpreter host/path, and executes the challenge in a non-persistent WKWebView; only the static consent preference is sent and token data remains memory-only.

CI run #136 built the XCFramework, generated the Xcode project, compiled and launched the iOS Simulator app, passed 5 unit tests with 0 failures, and created/uploaded an unsigned arm64 IPA. This is compile/package validation, not evidence of live YouTube playback or physical iPhone audio functionality.

The provider is a best-effort technical integration. A successful framework build does not guarantee that YouTube's live challenge protocol or any particular stream remains compatible.

## Runtime validation still required

- [ ] Live catalog search, suggestion, Home, Explore and continuation responses.
- [ ] At least one real song resolves to an HTTPS stream and produces audible output.
- [ ] Background audio continues while the iPhone screen is locked.
- [ ] Lock-screen / Control Center title, artist, artwork, play, pause, seek and skip.
- [ ] Phone/Siri interruptions, wired-headphone removal, Bluetooth disconnect and route changes.
- [ ] Wi-Fi and cellular changes during search and playback.
- [ ] Local playlists, favorites, history, TTML imports, Smart Mix and Spotify-imported playlists survive app relaunch.
- [ ] Public Spotify playlist metadata and strict track matching are validated against public, private, empty, malformed and 100+ track playlists.
- [ ] Lyrics provider fallback and manual provider selection behave when a provider has no match.
- [ ] Third-party service terms, attribution, GPL-3.0 obligations and privacy disclosures are reviewed before release.
- [ ] A signed physical-device TestFlight build passes regression testing.

## Source and license alignment

The iOS repository includes the Android MusikKu repository's GPL-3.0 license and third-party attribution notice. Native Swift files that port GPL-covered behaviour remain subject to applicable license obligations. Review third-party notices and distribution requirements before releasing binaries.
