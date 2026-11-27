import SwiftUI

struct ContentView: View {
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
        .onChange(of: playback.currentTrack?.id) { newID in
            guard newID != nil, let track = playback.currentTrack else { return }
            library.recordPlay(track)
        }
        .preferredColorScheme(.dark)
    }
}
