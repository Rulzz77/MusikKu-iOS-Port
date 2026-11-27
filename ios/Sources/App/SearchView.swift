import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var library: MusicLibraryStore
    @EnvironmentObject private var playback: PlaybackManager
    @State private var query = ""
    @State private var selectedFilter: CatalogSearchFilter = .all
    @State private var results: [CatalogItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasSearched = false
    @State private var continuationToken: String?
    @State private var isLoadingMore = false
    @State private var paginationError: String?
    @State private var selectedBrowseItem: CatalogItem?
    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 12)

                filterPicker
                    .padding(.bottom, 12)

                if isLoading {
                    ProgressView("Mencari katalog MusikKu…")
                        .tint(MusikKuStyle.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    statusView(
                        symbol: "wifi.exclamationmark",
                        title: "Pencarian belum berhasil",
                        message: errorMessage,
                        action: {
                            Task { await performSearch() }
                        }
                    )
                } else if results.isEmpty {
                    emptyContent
                } else {
                    resultList
                }
            }
            .background(MusikKuStyle.background.ignoresSafeArea())
            .navigationTitle("Cari Musik")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !query.isEmpty {
                        Button("Hapus") {
                            query = ""
                            results = []
                            continuationToken = nil
                            errorMessage = nil
                            paginationError = nil
                            hasSearched = false
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
        .sheet(item: $selectedBrowseItem) { item in
            if item.browseID != nil {
                CatalogBrowseDetailSheet(item: item)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.title3)
                .foregroundStyle(MusikKuStyle.secondary)

            TextField("Cari lagu, artis, atau album", text: $query)
                .font(.subheadline)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($searchFieldFocused)
                .onSubmit {
                    Task { await performSearch() }
                }

            if !query.isEmpty {
                Button {
                    query = ""
                    results = []
                    continuationToken = nil
                    hasSearched = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(MusikKuStyle.secondary)
                }
                .buttonStyle(.plain)
            }

            Button {
                searchFieldFocused = false
                Task { await performSearch() }
            } label: {
                Text("Cari")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(MusikKuStyle.accent.gradient, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(MusikKuStyle.surface, in: RoundedRectangle(cornerRadius: 15))
    }

    private var filterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CatalogSearchFilter.allCases) { filter in
                    Button {
                        guard selectedFilter != filter else { return }
                        selectedFilter = filter
                        if hasSearched {
                            Task { await performSearch() }
                        }
                    } label: {
                        Text(filter.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedFilter == filter ? .white : MusikKuStyle.secondary)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 9)
                            .background {
                                Capsule()
                                    .fill(selectedFilter == filter ? MusikKuStyle.accent : MusikKuStyle.surface)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
        }
    }

    private var resultList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                HStack {
                    Text("\(results.count) hasil")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MusikKuStyle.secondary)
                    Spacer()
                    Text("Katalog MusikKu")
                        .font(.caption)
                        .foregroundStyle(MusikKuStyle.secondary)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 9)

                ForEach(Array(results.enumerated()), id: \.offset) { index, item in
                    CatalogResultRow(
                        item: item,
                        isSaved: item.canSaveAsTrack && library.isFavorite(item.asMusicTrack()),
                        onSave: {
                            guard item.canSaveAsTrack else { return }
                            library.toggleFavorite(item.asMusicTrack())
                        },
                        onPlay: {
                            guard item.canSaveAsTrack else { return }
                            playback.play(item.asMusicTrack())
                        },
                        onOpen: {
                            guard item.browseID != nil else { return }
                            selectedBrowseItem = item
                        }
                    )
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .onAppear {
                        if index >= results.count - 5 {
                            Task { await loadMoreResults() }
                        }
                    }
                }

                if isLoadingMore {
                    ProgressView("Memuat hasil berikutnya…")
                        .tint(MusikKuStyle.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                } else if let paginationError {
                    Button(paginationError) {
                        Task { await loadMoreResults() }
                    }
                    .font(.caption)
                    .foregroundStyle(MusikKuStyle.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }

                Text("Tekan tombol putar pada lagu untuk mencoba streaming melalui pemutar MusikKu. Beberapa lagu mungkin tidak tersedia dari penyedia.")
                    .font(.caption)
                    .foregroundStyle(MusikKuStyle.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
            }
        }
    }

    @ViewBuilder
    private var emptyContent: some View {
        if hasSearched {
            statusView(
                symbol: "music.note",
                title: "Tidak ada hasil",
                message: "Coba kata kunci atau kategori pencarian yang berbeda.",
                action: nil
            )
        } else if library.recentSearches.isEmpty {
            statusView(
                symbol: "sparkle.magnifyingglass",
                title: "Temukan musik",
                message: "Cari lagu, artis, album, atau playlist dari katalog yang digunakan MusikKu Android.",
                action: nil
            )
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Pencarian terbaru")
                        .font(.headline)
                    Spacer()
                    Button("Hapus") { library.clearSearchHistory() }
                        .font(.caption)
                        .foregroundStyle(MusikKuStyle.secondary)
                }
                ForEach(library.recentSearches, id: \.self) { recent in
                    Button {
                        query = recent
                        Task { await performSearch() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(MusikKuStyle.secondary)
                            Text(recent)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.left")
                                .foregroundStyle(MusikKuStyle.secondary)
                        }
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func statusView(
        symbol: String,
        title: String,
        message: String,
        action: (() -> Void)?
    ) -> some View {
        VStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 38))
                .foregroundStyle(MusikKuStyle.accent)

            Text(title).font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(MusikKuStyle.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let action {
                Button("Coba lagi", action: action)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(MusikKuStyle.accent.opacity(0.2), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
    }

    @MainActor
    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        paginationError = nil
        continuationToken = nil
        results = []
        hasSearched = true
        defer { isLoading = false }

        do {
            let page = try await MusicCatalogService.shared.searchPage(
                query: trimmed,
                filter: selectedFilter
            )
            results = page.items
            continuationToken = page.continuation
            library.recordSearch(trimmed)
        } catch {
            results = []
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadMoreResults() async {
        guard !isLoading, !isLoadingMore,
              let token = continuationToken,
              !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isLoadingMore = true
        paginationError = nil
        defer { isLoadingMore = false }

        do {
            let page = try await MusicCatalogService.shared.searchContinuation(
                token: token,
                filter: selectedFilter
            )
            var known = Set(results.map { "\($0.kind.rawValue):\($0.id)" })
            results.append(contentsOf: page.items.filter {
                known.insert("\($0.kind.rawValue):\($0.id)").inserted
            })
            continuationToken = page.continuation
        } catch {
            paginationError = "Gagal memuat lagi. Ketuk untuk mencoba ulang."
        }
    }
}

private struct CatalogResultRow: View {
    let item: CatalogItem
    let isSaved: Bool
    let onSave: () -> Void
    let onPlay: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    artwork

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            if item.isExplicit {
                                Text("E")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(MusikKuStyle.secondary)
                                    .padding(3)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 3)
                                            .stroke(MusikKuStyle.secondary, lineWidth: 0.8)
                                    }
                            }
                        }

                        Text(item.artist.isEmpty ? item.subtitle : item.artist)
                            .font(.caption)
                            .foregroundStyle(MusikKuStyle.secondary)
                            .lineLimit(1)

                        HStack(spacing: 7) {
                            Text(kindLabel)
                            if let duration = item.durationSeconds {
                                Text("•")
                                Text(Self.time(duration))
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(MusikKuStyle.secondary)
                    }

                    if item.browseID != nil {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MusikKuStyle.secondary.opacity(0.7))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(item.browseID == nil)

            Spacer(minLength: 0)

            if item.canSaveAsTrack {
                Button(action: onPlay) {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(MusikKuStyle.accent)
                        .frame(width: 38, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Putar \(item.title)")

                Button(action: onSave) {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundStyle(isSaved ? .pink : MusikKuStyle.secondary)
                        .frame(width: 38, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSaved ? "Hapus dari lagu disukai" : "Simpan ke lagu disukai")
            }
        }
        .padding(9)
        .background(MusikKuStyle.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private var artwork: some View {
        AsyncImage(url: item.artworkURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .empty:
                placeholder.overlay { ProgressView().tint(MusikKuStyle.accent) }
            case .failure:
                placeholder
            @unknown default:
                placeholder
            }
        }
        .frame(width: 54, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(MusikKuStyle.accent.opacity(0.16))
            .overlay {
                Image(systemName: item.kind == .artist ? "person.fill" : "music.note")
                    .foregroundStyle(MusikKuStyle.accent)
            }
    }

    private var kindLabel: String {
        switch item.kind {
        case .song: return "Lagu"
        case .video: return "Video musik"
        case .album: return "Album"
        case .artist: return "Artis"
        case .playlist: return "Playlist"
        case .other: return "Musik"
        }
    }

    private static func time(_ seconds: Int) -> String {
        let safe = max(seconds, 0)
        let hours = safe / 3600
        let minutes = (safe % 3600) / 60
        let remainder = safe % 60
        if hours > 0 {
            return "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", remainder))"
        }
        return "\(minutes):\(String(format: "%02d", remainder))"
    }
}


struct CatalogBrowseDetailSheet: View {
    @EnvironmentObject private var library: MusicLibraryStore
    @EnvironmentObject private var playback: PlaybackManager
    @Environment(\.dismiss) private var dismiss
    let item: CatalogItem

    @State private var page: CatalogBrowsePage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isLoadingMore = false
    @State private var paginationError: String?
    @State private var selectedTrackToAddToPlaylist: MusicTrack?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && page == nil {
                    ProgressView("Memuat halaman katalog…")
                        .tint(MusikKuStyle.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let page {
                    detailContent(page)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 36))
                            .foregroundStyle(MusikKuStyle.accent)
                        Text("Halaman tidak dapat dimuat")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(MusikKuStyle.secondary)
                            .multilineTextAlignment(.center)
                        Button("Coba lagi") {
                            Task { await loadPage() }
                        }
                        .foregroundStyle(MusikKuStyle.accent)
                    }
                    .padding(26)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(MusikKuStyle.background.ignoresSafeArea())
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Tutup") { dismiss() }
                }
            }
        }
        .task { await loadPage() }
        .sheet(item: $selectedTrackToAddToPlaylist) { track in
            CatalogPlaylistPickerSheet(track: track)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func detailContent(_ page: CatalogBrowsePage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 15) {
                    AsyncImage(url: page.artworkURL ?? item.artworkURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .empty:
                            artworkPlaceholder.overlay { ProgressView().tint(MusikKuStyle.accent) }
                        case .failure:
                            artworkPlaceholder
                        @unknown default:
                            artworkPlaceholder
                        }
                    }
                    .frame(width: 112, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 7) {
                        Text(page.title)
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                            .lineLimit(3)

                        Text(page.subtitle.isEmpty ? item.kind.rawValue.capitalized : page.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(MusikKuStyle.secondary)
                            .lineLimit(3)

                        Text("\(page.tracks.count) lagu pada halaman ini")
                            .font(.caption)
                            .foregroundStyle(MusikKuStyle.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .background(MusikKuStyle.surface, in: RoundedRectangle(cornerRadius: 18))

                if !page.tracks.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Lagu")
                                .font(.headline)
                            Spacer()
                            Button {
                                let tracks = page.tracks
                                    .filter(\.canSaveAsTrack)
                                    .map { $0.asMusicTrack() }
                                guard !tracks.isEmpty else { return }
                                playback.playQueue(tracks)
                            } label: {
                                Label("Putar semua", systemImage: "play.fill")
                                    .font(.caption.weight(.semibold))
                            }
                            .disabled(!page.tracks.contains(where: \.canSaveAsTrack))
                            .foregroundStyle(MusikKuStyle.accent)
                        }

                        ForEach(Array(page.tracks.enumerated()), id: \.element.id) { index, track in
                            HStack(spacing: 11) {
                                AsyncImage(url: track.artworkURL) { phase in
                                    if case .success(let image) = phase {
                                        image.resizable().scaledToFill()
                                    } else {
                                        artworkPlaceholder
                                    }
                                }
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 9))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(track.title)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    Text(track.artist)
                                        .font(.caption)
                                        .foregroundStyle(MusikKuStyle.secondary)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 0)

                                Button {
                                    guard track.canSaveAsTrack else { return }
                                    playback.play(track.asMusicTrack())
                                } label: {
                                    Image(systemName: "play.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(MusikKuStyle.accent)
                                        .frame(width: 34, height: 38)
                                }
                                .buttonStyle(.plain)
                                .disabled(!track.canSaveAsTrack)
                                .accessibilityLabel("Putar \(track.title)")

                                Button {
                                    selectedTrackToAddToPlaylist = track.asMusicTrack()
                                } label: {
                                    Image(systemName: "text.badge.plus")
                                        .foregroundStyle(MusikKuStyle.secondary)
                                        .frame(width: 34, height: 38)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Tambah lagu ke playlist")

                                Button {
                                    library.toggleFavorite(track.asMusicTrack())
                                } label: {
                                    Image(systemName: library.isFavorite(track.asMusicTrack()) ? "heart.fill" : "heart")
                                        .foregroundStyle(library.isFavorite(track.asMusicTrack()) ? .pink : MusikKuStyle.secondary)
                                        .frame(width: 38, height: 38)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Simpan lagu ke favorit")
                            }
                            .padding(9)
                            .background(MusikKuStyle.surface, in: RoundedRectangle(cornerRadius: 13))
                            .onAppear {
                                if index >= page.tracks.count - 5 {
                                    Task { await loadMorePage() }
                                }
                            }
                        }
                    }
                }

                ForEach(page.shelves) { shelf in
                    CatalogDetailShelf(shelf: shelf)
                }

                if page.tracks.isEmpty && page.shelves.isEmpty {
                    Text("Belum ada daftar lagu atau shelf yang dapat ditampilkan untuk halaman ini.")
                        .font(.subheadline)
                        .foregroundStyle(MusikKuStyle.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(24)
                }

                if isLoadingMore {
                    HStack(spacing: 8) {
                        ProgressView().tint(MusikKuStyle.accent)
                        Text("Memuat daftar berikutnya…")
                            .font(.caption)
                            .foregroundStyle(MusikKuStyle.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                } else if let paginationError {
                    Button(paginationError) {
                        Task { await loadMorePage() }
                    }
                    .font(.caption)
                    .foregroundStyle(MusikKuStyle.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }

                Text("Pilih tombol putar untuk mencoba memutar lagu. Pemutaran bergantung pada ketersediaan stream dari penyedia musik.")
                    .font(.caption)
                    .foregroundStyle(MusikKuStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
        }
    }

    @MainActor
    private func loadMorePage() async {
        guard !isLoading, !isLoadingMore,
              let currentPage = page,
              let token = currentPage.continuation else { return }
        isLoadingMore = true
        paginationError = nil
        defer { isLoadingMore = false }

        do {
            let next = try await MusicCatalogService.shared.browseContinuation(
                token: token,
                browseID: currentPage.id
            )
            var merged = currentPage
            var knownTracks = Set(merged.tracks.map(\.id))
            merged.tracks.append(contentsOf: next.tracks.filter {
                knownTracks.insert($0.id).inserted
            })
            var knownShelves = Set(merged.shelves.map(\.id))
            merged.shelves.append(contentsOf: next.shelves.filter {
                knownShelves.insert($0.id).inserted
            })
            merged.continuation = next.continuation
            page = merged
        } catch {
            paginationError = "Gagal memuat halaman berikutnya. Ketuk untuk mencoba ulang."
        }
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(MusikKuStyle.accent.opacity(0.16))
            .overlay {
                Image(systemName: item.kind == .artist ? "person.fill" : "music.note")
                    .font(.title2)
                    .foregroundStyle(MusikKuStyle.accent)
            }
    }

    @MainActor
    private func loadPage() async {
        guard let browseID = item.browseID else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            page = try await MusicCatalogService.shared.browsePage(browseID: browseID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CatalogDetailShelf: View {
    let shelf: CatalogHomeShelf

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(shelf.title)
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(shelf.items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            AsyncImage(url: item.artworkURL) { phase in
                                if case .success(let image) = phase {
                                    image.resizable().scaledToFill()
                                } else {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(MusikKuStyle.accent.opacity(0.16))
                                }
                            }
                            .frame(width: 118, height: 118)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            Text(item.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(2)
                                .frame(width: 118, alignment: .leading)
                            Text(item.artist.isEmpty ? item.subtitle : item.artist)
                                .font(.caption2)
                                .foregroundStyle(MusikKuStyle.secondary)
                                .lineLimit(2)
                                .frame(width: 118, alignment: .leading)
                        }
                    }
                }
            }
        }
    }
}


private struct CatalogPlaylistPickerSheet: View {
    @EnvironmentObject private var library: MusicLibraryStore
    @Environment(\.dismiss) private var dismiss
    let track: MusicTrack

    var body: some View {
        NavigationStack {
            Group {
                if library.playlists.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 36))
                            .foregroundStyle(MusikKuStyle.accent)
                        Text("Belum ada playlist").font(.headline)
                        Text("Buat playlist dari tab Koleksi terlebih dahulu.")
                            .font(.subheadline)
                            .foregroundStyle(MusikKuStyle.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                } else {
                    List {
                        ForEach(library.playlists) { playlist in
                            let alreadyAdded = playlist.tracks.contains { $0.id == track.id }
                            Button {
                                library.add(track, to: playlist.id)
                                dismiss()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "music.note.list")
                                        .foregroundStyle(MusikKuStyle.accent)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(playlist.name)
                                            .foregroundStyle(.primary)
                                        Text("\(playlist.tracks.count) lagu")
                                            .font(.caption)
                                            .foregroundStyle(MusikKuStyle.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: alreadyAdded ? "checkmark.circle.fill" : "plus.circle")
                                        .foregroundStyle(alreadyAdded ? MusikKuStyle.secondary : MusikKuStyle.accent)
                                }
                            }
                            .disabled(alreadyAdded)
                            .listRowBackground(MusikKuStyle.surface)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(MusikKuStyle.background.ignoresSafeArea())
            .navigationTitle("Tambah ke playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Tutup") { dismiss() }
                }
            }
        }
    }
}
