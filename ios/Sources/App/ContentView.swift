import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var playback: PlaybackManager
    @State private var selectedTab: AppTab = .home
    @State private var isShowingNowPlaying = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(onExplore: { selectedTab = .search })
                .tabItem { Label("Beranda", systemImage: "house.fill") }
                .tag(AppTab.home)

            SearchView()
                .tabItem { Label("Cari", systemImage: "magnifyingglass") }
                .tag(AppTab.search)

            LibraryView()
                .tabItem { Label("Koleksi", systemImage: "square.stack.fill") }
                .tag(AppTab.library)
        }
        .tint(MusikKuStyle.accent)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let track = playback.currentTrack {
                MiniPlayerBar(track: track) {
                    isShowingNowPlaying = true
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 4)
                .background(MusikKuStyle.background.opacity(0.96))
            }
        }
        .sheet(isPresented: $isShowingNowPlaying) {
            NowPlayingView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .preferredColorScheme(.dark)
    }
}

private enum AppTab: Hashable {
    case home
    case search
    case library
}
