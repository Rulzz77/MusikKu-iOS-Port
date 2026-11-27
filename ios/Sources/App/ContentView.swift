import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var playback: PlaybackManager
    @EnvironmentObject private var library: MusicLibraryStore
    @State private var selectedTab: AppMainTab = .home
    @State private var isShowingNowPlaying = false
    @State private var isShowingSearch = false

    var body: some View {
        Group {
            switch selectedTab {
            case .home:
                HomeView(
                    onExplore: { selectedTab = .explore },
                    onSearch: { isShowingSearch = true }
                )
            case .explore:
                ExploreView(onSearch: { isShowingSearch = true })
            case .library:
                LibraryView(onSearch: { isShowingSearch = true })
            }
        }
        .background(MusikKuStyle.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingMusicDock(
                selectedTab: selectedTab,
                onSelectTab: { selectedTab = $0 },
                onOpenPlayer: { isShowingNowPlaying = true }
            )
        }
        .sheet(isPresented: $isShowingNowPlaying) {
            NowPlayingView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingSearch) {
            SearchView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: playback.playbackStartID) { _ in
            guard let track = playback.currentTrack else { return }
            library.recordPlay(track)
        }

        .onChange(of: playback.currentTrack?.id) { _ in
            library.flushListeningStats()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                library.flushListeningStats()
            }
        }

        .onChange(of: playback.playbackHeartbeatID) { _ in
            guard let track = playback.currentTrack else { return }
            library.recordListenProgress(track, seconds: 0.5)
        }
        .preferredColorScheme(.dark)
    }
}
