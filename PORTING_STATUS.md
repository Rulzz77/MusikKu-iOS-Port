# Porting status

Current state: **iOS starter only — not a complete MusikKu port.**

Implemented in this scaffold:
- SwiftUI application entry point and first player screen.
- AVPlayer wrapper with audio session activation.
- Basic play / pause / seek.
- Basic Now Playing metadata and lock-screen / Control Center commands.
- XcodeGen project specification and unsigned iOS Simulator CI workflow.
- Repository audit and feature migration plan.

Not yet integrated:
- Any production music catalog or stream resolver.
- Authentication, persistence, playlists, favorites, lyrics, recommendation engine, or sync.
- Native DSP, equalizer, crossfade, advanced codec, and device-routing parity.
- TestFlight or App Store release signing.

No claim is made that the starter has been compiled or tested in Xcode in this environment. The first real validation must run on a Mac with Xcode, followed by physical-device audio tests.
