# Porting status

Current state: **iOS foundation + first UI/library milestone — not a complete MusikKu port.**

Implemented in this milestone:
- SwiftUI app with Beranda, Cari, and Koleksi tabs.
- Home screen with clear catalog-connection status and player surface.
- Local playlist creation and deletion.
- Local favorites and playlist persistence using versioned UserDefaults JSON keys.
- Library store methods to add/remove a track from a playlist and toggle favorites.
- AVPlayer queue foundation: play a queue, enqueue, next, previous, and automatic advance at end of item.
- Lock-screen / Control Center play, pause, next, previous, and 15-second seek commands.
- Audio interruption handling and playback error reporting for failed AVPlayer items.
- XcodeGen project specification and unsigned iOS Simulator CI workflow.

Still not integrated:
- Any production music catalog or stream resolver.
- UI flow to add catalog tracks into playlists/favorites; it will be connected with the catalog milestone.
- Authentication, token refresh, account sync, or secure account storage.
- Timed lyrics and translation providers.
- Recommendation engine, listening history, and cross-device sync.
- Native DSP, equalizer, crossfade, advanced codec, and specialized device-routing parity.
- TestFlight or App Store release signing.

The app deliberately does not include unofficial stream extraction or claim that Android YouTube Music playback is iOS/App Store-ready. The next milestone is to select an authorized catalog provider and connect search results to `MusicTrack.streamURL`.

Validation note: the initial starter commit passed the GitHub Actions iOS Simulator build. This milestone must pass a new CI build before it is considered build-verified. Physical-device background playback and interruption tests remain outstanding.
