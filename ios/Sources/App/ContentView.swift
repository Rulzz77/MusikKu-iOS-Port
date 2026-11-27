import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .home

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
        .preferredColorScheme(.dark)
    }
}

private enum AppTab: Hashable {
    case home
    case search
    case library
}
