# Porting status

Current state: **native iOS UI + local library + read-only catalog search — not a complete MusikKu port.**

Implemented in the current development branch:
- SwiftUI app with Beranda, Cari, and Koleksi tabs.
- Persistent local playlists and favorites using versioned UserDefaults JSON keys.
- Playlist detail can play a playlist in order and remove tracks when a track has an authorized stream URL.
- AVPlayer queue foundation: play a queue, enqueue, remove a queue item, next, previous, shuffle, repeat-one, and automatic advance at end of item.
- Mini-player and full Now Playing screen with artwork, seek, favorite, add-to-playlist, and queue inspection/removal.
- Lock-screen / Control Center play, pause, next, previous, seek, and asynchronously loaded artwork.
- Audio interruption and headphone-removal pause handling.
- Read-only YouTube Music search using the same anonymous WEB_REMIX endpoint, client identity, and filter parameters used in the Android repository.
- Search filters for all, songs, videos, albums, artists, and playlists.
- Search result artwork, artist/title/duration metadata, explicit marker where exposed, and local save-to-favorites for track/video results.
- Upstream GPL-3.0 license and third-party notices copied into this derivative repository.

Still not integrated:
- Native audio stream resolver. Search results currently have no playable stream URL and cannot start AVPlayer.
- Home feed shelves, album/artist/playlist detail browsing, suggestions, and search continuation paging.
- Authenticated Google/YouTube account sessions, account/channel switching, library writes, and server-synced likes/playlists.
- Other Android catalogue/add-on sources such as JioSaavn and custom modules.
- Timed lyrics, translations, provider selection, and local TTML import.
- Download manager, offline audio, listening history, recommendations, smart playlists, and cross-device sync.
- Native DSP, equalizer, crossfade, advanced codecs, USB audio, and specialized device-routing parity.
- TestFlight or App Store release signing.

The catalog adapter makes anonymous read-only search requests. It does not send Google cookies or account credentials and does not change any account. Playback still requires a native resolver that returns a valid stream URL from a source authorized for this app.

Validation:
- Starter and first UI/player milestones passed the GitHub Actions iOS Simulator build.
- The catalog search milestone is pending a fresh CI build.
- Physical-iPhone playback, background audio, route, and lock-screen tests remain outstanding.
