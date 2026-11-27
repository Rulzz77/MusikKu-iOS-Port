import SwiftUI

@main
struct MusikKuApp: App {
    @StateObject private var playback = PlaybackManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(playback)
                .preferredColorScheme(.dark)
        }
    }
}
