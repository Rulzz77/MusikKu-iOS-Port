import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var playback: PlaybackManager
    @EnvironmentObject private var library: MusicLibraryStore
    @State private var homeShelves: [CatalogHomeShelf] = []
    @State private var isLoadingHome = false
    @State private var homeErrorMessage: String?
    @State private var didLoadHome = false
    @State private var homeContinuation: String?
    @State private var isLoadingMoreHome = false
    @State private var selectedHomeBrowseItem: CatalogItem?
    let onExplore: () -> Void
    let onSearch: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    VStack(alignment: .leading, spacing: 9) {
                        Text("Musik kamu,\ncara dengarmu.")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Satu tempat untuk lagu dan koleksi favoritmu.")
                            .font(.subheadline)
                            .foregroundStyle(MusikKuStyle.secondary)
                    }

                    if !library.recentlyPlayed.isEmpty {
                        recentlyPlayedSection
                    }

                    if library.mostPlayed.count >= 2 {
                        frequentMixCard
                    }

                    homeFeedContent

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Perpustakaan kamu")
                            .font(.headline)
                        HStack(spacing: 12) {
                            LibrarySummaryCard(
                                title: "Playlist",
                                count: library.playlists.count,
                                symbol: "music.note.list"
                            )
                            LibrarySummaryCard(
                                title: "Lagu disukai",
                                count: library.favorites.count,
                                symbol: "heart.fill"
                            )
                        }
                    }
                }
                .padding(20)
            }
            .background(MusikKuStyle.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await loadHomeFeed()
            }
            .sheet(item: $selectedHomeBrowseItem) { item in
                CatalogBrowseDetailSheet(item: item)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var homeFeedContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            if homeShelves.isEmpty {
                catalogCard

                if isLoadingHome {
                    HStack(spacing: 10) {
                        ProgressView().tint(MusikKuStyle.accent)
                        Text("Memuat rekomendasi MusikKu…")
                            .font(.caption)
                            .foregroundStyle(MusikKuStyle.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                }

                if let homeErrorMessage {
                    VStack(alignment: .leading, spacing: 9) {
                        Text(homeErrorMessage)
                            .font(.caption)
                            .foregroundStyle(MusikKuStyle.secondary)

                        Button {
                            didLoadHome = false
                            Task { await loadHomeFeed() }
                        } label: {
                            Label("Muat ulang Beranda", systemImage: "arrow.clockwise")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(MusikKuStyle.accent)
                    }
                }
            } else {
                ForEach(Array(homeShelves.enumerated()), id: \.element.id) { index, shelf in
                    CatalogHomeShelfSection(shelf: shelf) { item in
                        if item.canSaveAsTrack {
                            playback.play(item.asMusicTrack())
                        } else if item.browseID != nil {
                            selectedHomeBrowseItem = item
                        }
                    }
                    .onAppear {
                        if index >= homeShelves.count - 2 {
                            Task { await loadMoreHomeFeed() }
                        }
                    }
                }

                if isLoadingMoreHome {
                    ProgressView("Memuat rekomendasi berikutnya…")
                        .tint(MusikKuStyle.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }

                Text("Ketuk lagu untuk mencoba memutarnya melalui pemutar MusikKu. Ketersediaan audio bergantung pada penyedia musik.")
                    .font(.caption)
                    .foregroundStyle(MusikKuStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var recentlyPlayedSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("Baru diputar")
                    .font(.headline)
                Spacer()
                Text("Riwayat lokal")
                    .font(.caption)
                    .foregroundStyle(MusikKuStyle.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(library.recentlyPlayed.prefix(12))) { track in
                        Button {
                            playback.play(track)
                        } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                ArtworkView(track: track, cornerRadius: 14)
                                    .frame(width: 126, height: 126)
                                Text(track.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(2)
                                    .frame(width: 126, alignment: .leading)
                                Text(track.artist)
                                    .font(.caption)
                                    .foregroundStyle(MusikKuStyle.secondary)
                                    .lineLimit(1)
                                    .frame(width: 126, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var frequentMixCard: some View {
        let mixTracks = Array(library.mostPlayed.prefix(25))
        return Button {
            playback.playQueue(mixTracks)
        } label: {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [MusikKuStyle.accent, Color(red: 0.20, green: 0.72, blue: 0.67)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "waveform.path")
                        .font(.system(size: 27, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Mix favoritmu")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Urutan dibuat dari lagu yang paling sering kamu putar")
                        .font(.caption)
                        .foregroundStyle(MusikKuStyle.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "play.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(MusikKuStyle.accent.gradient, in: Circle())
            }
            .padding(14)
            .background(MusikKuStyle.surface, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func loadHomeFeed() async {
        guard !didLoadHome else { return }
        didLoadHome = true
        isLoadingHome = true
        homeErrorMessage = nil
        defer { isLoadingHome = false }

        do {
            let page = try await MusicCatalogService.shared.homeFeedPage()
            homeShelves = page.shelves
            homeContinuation = page.continuation
            if homeShelves.isEmpty {
                homeErrorMessage = "Belum ada rekomendasi yang dikirim katalog untuk sesi ini."
            }
        } catch {
            homeErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadMoreHomeFeed() async {
        guard !isLoadingMoreHome, let token = homeContinuation else { return }
        isLoadingMoreHome = true
        defer { isLoadingMoreHome = false }

        do {
            let page = try await MusicCatalogService.shared.homeContinuation(token: token)
            var known = Set(homeShelves.map(\.id))
            homeShelves.append(contentsOf: page.shelves.filter { known.insert($0.id).inserted })
            homeContinuation = page.continuation
        } catch {
            homeErrorMessage = "Rekomendasi berikutnya gagal dimuat."
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(MusikKuStyle.accent.gradient, in: RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 1) {
                Text("MusikKu").font(.headline)
                Text("MUSIC FOR YOUR MOMENT")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(MusikKuStyle.secondary)
            }

            Spacer()

            Button(action: onSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(MusikKuStyle.secondary)
                    .frame(width: 42, height: 42)
                    .background(MusikKuStyle.surfaceVariant, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cari musik")
        }
    }

    private var catalogCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("KATALOG MUSIK", systemImage: "music.note.list")
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(MusikKuStyle.secondary)

                Spacer()

                Text(isLoadingHome ? "MEMUAT" : (homeErrorMessage == nil ? "KATALOG" : "PERIKSA KONEKSI"))
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.6)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(.orange.opacity(0.16), in: Capsule())
                    .foregroundStyle(.orange)
            }

            Text("Musik akan muncul di sini")
                .font(.title3.bold())

            Text("Cari lagu untuk melihat katalog, lalu gunakan tombol putar untuk mencoba streaming audio.")
                .font(.subheadline)
                .foregroundStyle(MusikKuStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onExplore) {
                Label("Jelajahi mood dan genre", systemImage: "safari")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(MusikKuStyle.accent.opacity(0.2), in: RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
        }
        .padding(17)
        .background(MusikKuStyle.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        }
    }


}

private struct LibrarySummaryCard: View {
    let title: String
    let count: Int
    let symbol: String

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(MusikKuStyle.accent)
                .frame(width: 38, height: 38)
                .background(MusikKuStyle.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text("\(count)").font(.title3.bold())
                Text(title)
                    .font(.caption)
                    .foregroundStyle(MusikKuStyle.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MusikKuStyle.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}


private struct CatalogHomeShelfSection: View {
    let shelf: CatalogHomeShelf
    let onOpen: (CatalogItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            VStack(alignment: .leading, spacing: 3) {
                Text(shelf.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if !shelf.subtitle.isEmpty {
                    Text(shelf.subtitle)
                        .font(.caption)
                        .foregroundStyle(MusikKuStyle.secondary)
                        .lineLimit(2)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(shelf.items) { item in
                        CatalogHomeItemCard(item: item) {
                            onOpen(item)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct CatalogHomeItemCard: View {
    let item: CatalogItem
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 7) {
                AsyncImage(url: item.artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty:
                        placeholder.overlay {
                            ProgressView().tint(MusikKuStyle.accent)
                        }
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
                .frame(width: 142, height: 142)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(width: 142, alignment: .leading)

                Text(item.artist.isEmpty ? item.subtitle : item.artist)
                    .font(.caption)
                    .foregroundStyle(MusikKuStyle.secondary)
                    .lineLimit(2)
                    .frame(width: 142, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!item.canSaveAsTrack && item.browseID == nil)
        .accessibilityElement(children: .combine)
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(MusikKuStyle.accent.opacity(0.16))
            .overlay {
                Image(systemName: item.kind == .artist ? "person.fill" : "music.note")
                    .font(.title2)
                    .foregroundStyle(MusikKuStyle.accent)
            }
    }
}
