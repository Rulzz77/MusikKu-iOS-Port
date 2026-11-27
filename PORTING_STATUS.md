# Porting status

Current state: **iOS foundation + interactive player/library UI — not a complete MusikKu port.**

Implemented in the current development branch:
- SwiftUI app with Beranda, Cari, and Koleksi tabs.
- Persistent local playlists and favorites using versioned UserDefaults JSON keys.
- Playlist detail can play a playlist in order and remove tracks.
- Favorites can be played from the library.
- AVPlayer queue foundation: play a queue, enqueue, remove a queue item, next, previous, shuffle, repeat-one, and automatic advance at end of item.
- Mini-player appears while a track is selected and opens a full Now Playing screen.
- Full player supports artwork display, seek, play/pause, next/previous, shuffle, repeat-one, favorite toggle, add-to-playlist, and queue inspection/removal.
- Lock-screen / Control Center play, pause, next, previous, and 15-second seek commands.
- Audio interruption handling and playback error reporting for failed AVPlayer items.
- XcodeGen project specification and unsigned iOS Simulator CI workflow.

Still not integrated:
- Any production music catalog, authorized stream resolver, or online search provider.
- Authentication, token refresh, account sync, or secure account storage.
- Timed lyrics and translation providers.
- Recommendation engine, listening history, and cross-device sync.
- Native DSP, equalizer, crossfade, advanced codec, and specialized device-routing parity.
- TestFlight or App Store release signing.

The app deliberately does not include unofficial stream extraction or claim that Android YouTube Music playback is iOS/App Store-ready. Playback requires a valid stream URL from a provider authorized for use in this app.

Validation:
- Starter commit passed the GitHub Actions iOS Simulator build.
- First UI/library milestone passed the GitHub Actions iOS Simulator build.
- The new full-player/queue/favorites UI changes are pending a fresh CI build.
- Physical-device background playback and interruption tests remain outstanding.
