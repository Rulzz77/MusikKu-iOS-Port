# Feature Migration Matrix

This matrix distinguishes source implementation from runtime validation. A native iOS screen or successful simulator build does not prove that a remote provider, BotGuard challenge, audio stream, or physical-device audio route works.

| Android MusikKu capability | iOS implementation | Status |
|---|---|---|
| Main navigation | SwiftUI Beranda / Explore / Koleksi tabs; global search sheet; floating material dock with mini-player | Implemented in source; latest visual changes still require CI validation |
| Android visual language | Dark BitChord palette, lavender accent, rounded cards, artwork shelves, floating translucent dock | Adapted to SwiftUI; pixel-identical parity is not intended |
| Home feed | WEB_REMIX FEmusic_home, artwork shelves, recent plays, play-count Mix, continuation paging | Implemented in source; live response/pagination needs device testing |
| Explore / mood / genre | FEmusic_moods_and_genres, category grid, browse detail, category continuation paging | Implemented in source; parser depends on live third-party response format |
| Search | WEB_REMIX all/song/video/album/artist/playlist filters, query suggestions, local recent-search list, result continuation paging | Implemented in source; live suggestions/continuation requests need runtime validation |
| Album / artist / playlist pages | Header/artwork, track rows, related shelves, play-all, save/favorite, continuation paging | Implemented in source; deep nested browse parity remains incomplete |
| Local playlists / favorites | Create/delete local playlists, add/remove tracks, favorites | Implemented with local UserDefaults persistence; no account required |
| Listening history / statistics | Locally records play starts, last-played timestamp and play count | Implemented in source; only local to this device |
| Mix / Smart Playlists | Play-count Mix; saved local rules with minimum play count, optional artist filter, most-played/recent sorting | Basic subset implemented; Android's full rules (genre, year, duration, date windows, ALL/ANY match) remain unported |
| Player / queue | AVPlayer queue, enqueue/remove, next/previous, shuffle, repeat-one, auto advance, manual queue reordering | Implemented in source; playback reliability requires physical-device verification |
| Now Playing | Artwork, seek, favorite, add-to-playlist, lyrics sheet, queue sheet, mini-player | Implemented in source; further Android player customisation remains |
| Lock screen / Control Center | MPNowPlayingInfoCenter, MPRemoteCommandCenter, artwork, transport and seek | Implemented in source; must be verified on a physical iPhone |
| Background audio / interruptions | AVAudioSession playback, background audio mode, interruption and headphone-removal handling | Configured in source; physical-device and Bluetooth tests pending |
| Lyrics | lrc.red, BiniLyrics, BetterLyrics, BetterLyrics Portato, LRCLIB fallback; TTML line/word/syllable timing | Core provider chain implemented; translation/provider settings/local TTML import/export remain |
| Resolver / YouTube stream | Kotlin Multiplatform InnerTubeX v0.7.0, Ktor Darwin, HTTPS audio handoff, iOS WEB_BOTGUARD provider | XCFramework/build and prior simulator launch pass; live challenge execution, PoToken generation, stream extraction and audible playback unverified |
| Guest-first usage | Local library actions do not require account login | Implemented for local data; no cloud sync |
| Google / YouTube account, remote likes | Approved OAuth, account/channel switching and account-backed library | Not implemented |
| Additional Android sources / add-ons | Separate provider adapters and source-specific terms/permissions | Not implemented |
| External playlist import | Provider-specific import adapters and permission review | Not implemented |
| Offline downloads | User's current iOS direction is online catalog playback | Not in current iOS scope |
| Full Android DSP / equalizer / crossfade | Native audio processing and AVPlayer/AVAudioEngine integration | Not implemented |
| Listen Together / party sync | New native iOS client and protocol testing | Not implemented |
| USB exclusive / bit-perfect / advanced codecs | Reassess against iOS audio-session and accessory APIs | Not implemented; no parity claim |
| Android APK updater | TestFlight / App Store distribution | Not applicable on iOS |
| Release signing | Apple signing, provisioning and App Store Connect | Not configured; current GitHub artifact is unsigned for Sideloadly testing |

## Resolver architecture

The iOS target consumes a Kotlin Multiplatform framework built from resolver-kmp. It pins InnerTubeX v0.7.0, matching Android. The iOS adapter uses Ktor Darwin and requests direct audio streams with HLS/SABR disabled before passing the HTTPS URL and required request headers to AVPlayer. The iOS WEB_BOTGUARD provider executes challenge JavaScript in a non-persistent WKWebView and sends fixed HTTPS requests through Ktor Darwin. Tokens are memory-only; Google account cookies are not read or sent.

The provider is a best-effort technical integration. A successful framework build does not guarantee that YouTube's live challenge protocol or any particular stream remains compatible.

## Runtime validation still required

- [ ] Live catalog search, suggestion, Home, Explore and continuation responses.
- [ ] At least one real song resolves to an HTTPS stream and produces audible output.
- [ ] Background audio continues while the iPhone screen is locked.
- [ ] Lock-screen / Control Center title, artist, artwork, play, pause, seek and skip.
- [ ] Phone/Siri interruptions, unplugging wired headphones, Bluetooth disconnect and route changes.
- [ ] Wi-Fi and cellular changes during search and playback.
- [ ] Local playlists, favorites, history and Smart Mix survive app relaunch.
- [ ] Lyrics fallback behaves when no provider has a match.
- [ ] Third-party service terms, attribution, GPL-3.0 obligations and privacy disclosures are reviewed before release.
- [ ] A signed physical-device TestFlight build passes regression testing.

## Source and license alignment

The iOS repository includes the Android MusikKu repository's GPL-3.0 license and third-party attribution notice. Native Swift files that port GPL-covered behaviour remain subject to applicable license obligations. Review third-party notices and distribution requirements before releasing binaries.