# Feature Migration Matrix

| Android MusikKu capability | iOS direction | Status in this starter |
|---|---|---|
| Discover / search catalog | Authorized provider adapter over URLSession / Ktor Darwin | Anonymous WEB_REMIX search filters, first-page FEmusic_home shelves, and first-page album/artist/playlist browse details; metadata only, no paging yet |
| Remote audio playback | AVPlayer / AVQueuePlayer | AVPlayer foundation; no native stream resolver connected to catalog results yet |
| Background playback | AVAudioSession `.playback` + iOS background audio mode | Declared; physical-device verification outstanding |
| Lock-screen / Control Center | MPNowPlayingInfoCenter + MPRemoteCommandCenter | Basic metadata and play/pause/skip/next/previous commands |
| Play queue / next / previous | Shared pure queue model + native player queue controller | AVPlayer queue controller foundation implemented |
| Liked songs / playlists | SwiftData / Core Data or shared persistence adapter | Local UserDefaults JSON store; UI creates/deletes playlists |
| Guest usage | Local guest store; no login gate for local actions | Local playlist/favorites storage foundation |
| Login / account | Provider-approved OAuth + Keychain | Not implemented |
| Lyrics | Provider adapters using URLSession / Ktor Darwin | Not implemented; Android provider list/model audited |
| Translation | Provider adapter; cache and attribution | Not implemented |
| Smart Playlists | Reuse pure filters and sorting after KMP extraction | Not implemented |
| Listening history / statistics | Shared domain model + local persistence | Not implemented |
| Spotify playlist import | Official API / approved OAuth scopes and terms | Not implemented |
| Listen Together | Existing Go protocol can be evaluated; new iOS client required | Not implemented |
| Android APK updater | Replace with TestFlight / App Store updates | Not applicable on iOS |
| ExoPlayer / Media3 | AVPlayer or custom AVAudioEngine path | Replaced only in starter |
| C++ JNI / ONNX | Rebuild for Apple targets; replace JNI and Android-specific runtime | Not implemented |
| USB exclusive / bit-perfect | Reassess against iOS audio and accessory APIs | Not promised |
| DSD / DST codecs | Port/test each decoder and license independently | Not implemented |
| Car Mode / widgets | CarPlay / WidgetKit design and entitlement review | Not implemented |
| Android TV / Wear OS | Separate Apple TV / watchOS products only if required | Out of current scope |

## Source and license alignment

The iOS repository includes the Android MusikKu repository's GPL-3.0 license and upstream attribution notice. Native Swift files that port GPL-covered behaviour remain subject to the applicable license terms. Review third-party notices and distribution obligations before releasing binaries.

## Source and license alignment

The iOS repository includes the Android MusikKu repository's GPL-3.0 license and upstream attribution notice. Native Swift files that port GPL-covered behaviour remain subject to the applicable license terms. Review third-party notices and distribution obligations before releasing binaries.

## Definition of done for first iOS beta

- [ ] Approved catalog source and written terms/permission evidence.
- [ ] Catalog search returns real tracks with stable IDs and artwork.
- [ ] Audio playback is reliable over HTTPS on Wi-Fi and cellular.
- [ ] Background audio continues with the screen locked.
- [ ] Lock-screen / Control Center title, artist, artwork, play, pause, and skip behave correctly.
- [ ] Audio interruptions (phone call, Siri, route change, Bluetooth disconnect) are handled.
- [ ] Guest playlists / favorites / queue survive relaunch.
- [ ] Lyrics fall back gracefully when no provider has a match.
- [ ] Privacy disclosures and third-party notices are complete.
- [ ] Physical-device TestFlight build passes a regression checklist.
