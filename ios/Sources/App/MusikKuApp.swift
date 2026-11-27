import SwiftUI

@main
struct MusikKuApp: App {
    @StateObject private var playback = PlaybackManager()
    @StateObject private var library = MusicLibraryStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(playback)
                .environmentObject(library)
                .preferredColorScheme(.dark)
        }
    }
}
