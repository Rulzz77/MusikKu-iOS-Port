import SwiftUI

struct ExploreView: View {
    @State private var categories: [CatalogMoodGenre] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didLoad = false
    @State private var selectedCategory: CatalogMoodGenre?
    let onSearch: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Explore")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("Temukan musik sesuai suasana dan aktivitasmu.")
                            .font(.subheadline)
                            .foregroundStyle(MusikKuStyle.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)

                    if isLoading && categories.isEmpty {
                        ProgressView("Memuat mood dan genre…")
                            .tint(MusikKuStyle.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 38)
                    } else if let errorMessage, categories.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "wifi.exclamationmark")
                                .font(.system(size: 34))
                                .foregroundStyle(MusikKuStyle.accent)
                            Text("Explore belum bisa dimuat")
                                .font(.headline)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(MusikKuStyle.secondary)
                                .multilineTextAlignment(.center)
                            Button("Coba lagi") {
                                didLoad = false
                                Task { await loadCategories() }
                            }
                            .font(.subheadline.weight(.semibold))
                            .buttonStyle(.borderedProminent)
                            .tint(MusikKuStyle.accent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(categories) { category in
                                Button {
                                    selectedCategory = category
                                } label: {
                                    MoodGenreTile(category: category)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if isLoading && !categories.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView().tint(MusikKuStyle.accent)
                            Text("Memuat sampul kategori…")
                                .font(.caption)
                                .foregroundStyle(MusikKuStyle.secondary)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
            .background(MusikKuStyle.background.ignoresSafeArea())
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onSearch) {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Cari musik")
                }
            }
            .task {
                await loadCategories()
            }
            .sheet(item: $selectedCategory) { category in
                ExploreCategoryDetailSheet(category: category)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    @MainActor
    private func loadCategories() async {
        guard !didLoad else { return }
        didLoad = true
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            categories = try await MusicCatalogService.shared.moodAndGenres()
            if categories.isEmpty {
                errorMessage = "Katalog belum mengirim kategori mood dan genre."
                return
            }
            await loadArtworkForVisibleCategories()
        } catch {
            errorMessage = MusikKuErrorMessage.indonesianMessage(for: error, fallback: "Mood dan genre belum dapat dimuat. Periksa koneksi lalu coba lagi.")
        }
    }

    @MainActor
    private func loadArtworkForVisibleCategories() async {
        let visible = Array(categories.prefix(12))
        for start in stride(from: 0, to: visible.count, by: 4) {
            let end = min(start + 4, visible.count)
            let batch = Array(visible[start..<end])
            let results = await withTaskGroup(of: (String, URL?).self) { group in
                for category in batch {
                    group.addTask {
                        do {
                            let page = try await MusicCatalogService.shared.browsePage(
                                browseID: category.browseID,
                                params: category.params
                            )
                            let firstArtwork = page.shelves
                                .flatMap { $0.items }
                                .compactMap { $0.artworkURL }
                                .first
                            return (category.id, firstArtwork ?? page.artworkURL)
                        } catch {
                            return (category.id, nil)
                        }
                    }
                }

                var resolved: [(String, URL?)] = []
                for await value in group {
                    resolved.append(value)
                }
                return resolved
            }

            for (id, artworkURL) in results {
                guard let artworkURL,
                      let index = categories.firstIndex(where: { $0.id == id }) else { continue }
                categories[index].artworkURL = artworkURL
            }
        }
    }
}

private struct MoodGenreTile: View {
    let category: CatalogMoodGenre

    private var tint: Color {
        guard let argb = category.stripeColor else { return MusikKuStyle.accent }
        let red = Double((argb >> 16) & 0xFF) / 255
        let green = Double((argb >> 8) & 0xFF) / 255
        let blue = Double(argb & 0xFF) / 255
        return Color(red: red, green: green, blue: blue)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .fill(tint.gradient)

            if let artworkURL = category.artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        LinearGradient(
                            colors: [tint.opacity(0.95), tint.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 132)
                .clipped()
                .blendMode(.luminosity)
                .opacity(0.82)
            } else {
                Image(systemName: "waveform")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(14)
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.72)],
                startPoint: .center,
                endPoint: .bottom
            )

            Text(category.title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(13)
        }
        .frame(height: 132)
        .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: tint.opacity(0.15), radius: 12, y: 5)
    }
}

private struct ExploreCategoryDetailSheet: View {
    @EnvironmentObject private var playback: PlaybackManager
    @Environment(\.dismiss) private var dismiss
    @State private var page: CatalogBrowsePage?
    @State private var selectedBrowseItem: CatalogItem?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var paginationError: String?
    @State private var errorMessage: String?
    let category: CatalogMoodGenre

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && page == nil {
                    ProgressView("Memuat pilihan musik…")
                        .tint(MusikKuStyle.accent)
                } else if let errorMessage, page == nil {
                    VStack(spacing: 12) {
                        Text("Kategori belum bisa dibuka")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(MusikKuStyle.secondary)
                            .multilineTextAlignment(.center)
                        Button("Coba lagi") { Task { await loadCategory() } }
                            .buttonStyle(.borderedProminent)
                            .tint(MusikKuStyle.accent)
                    }
                    .padding(24)
                } else if let page {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if let artworkURL = page.artworkURL {
                                AsyncImage(url: artworkURL) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFill()
                                    } else {
                                        categoryPlaceholder
                                    }
                                }
                                .frame(height: 190)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                            }

                            if !page.subtitle.isEmpty {
                                Text(page.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(MusikKuStyle.secondary)
                            }

                            ForEach(Array(page.shelves.enumerated()), id: \.element.id) { index, shelf in
                                ExploreCategoryShelf(shelf: shelf) { item in
                                    open(item)
                                }
                                .onAppear {
                                    if index == page.shelves.count - 1 && page.tracks.isEmpty {
                                        Task { await loadMoreCategoryPage() }
                                    }
                                }
                            }

                            if !page.tracks.isEmpty {
                                VStack(alignment: .leading, spacing: 9) {
                                    Text("Lagu")
                                        .font(.headline)
                                    ForEach(Array(page.tracks.enumerated()), id: \.element.id) { index, item in
                                        ExploreCategoryTrack(item: item) {
                                            open(item)
                                        }
                                        .onAppear {
                                            if index >= page.tracks.count - 5 {
                                                Task { await loadMoreCategoryPage() }
                                            }
                                        }
                                    }
                                }
                            }

                            if page.shelves.isEmpty && page.tracks.isEmpty {
                                Text("Belum ada daftar musik untuk kategori ini.")
                                    .font(.subheadline)
                                    .foregroundStyle(MusikKuStyle.secondary)
                            }

                            if isLoadingMore {
                                ProgressView("Memuat pilihan berikutnya…")
                                    .tint(MusikKuStyle.accent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            } else if let paginationError {
                                Button(paginationError) {
                                    Task { await loadMoreCategoryPage() }
                                }
                                .font(.caption)
                                .foregroundStyle(MusikKuStyle.accent)
                            }
                        }
                        .padding(18)
                    }
                    .background(MusikKuStyle.background.ignoresSafeArea())
                }
            }
            .background(MusikKuStyle.background.ignoresSafeArea())
            .navigationTitle(page?.title ?? category.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Tutup") { dismiss() }
                }
            }
            .task {
                await loadCategory()
            }
            .sheet(item: $selectedBrowseItem) { item in
                CatalogBrowseDetailSheet(item: item)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var categoryPlaceholder: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(MusikKuStyle.accent.opacity(0.22))
            .overlay {
                Image(systemName: "waveform")
                    .font(.system(size: 42))
                    .foregroundStyle(MusikKuStyle.accent)
            }
    }

    @MainActor
    private func loadCategory() async {
        guard page == nil else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            page = try await MusicCatalogService.shared.browsePage(
                browseID: category.browseID,
                params: category.params
            )
        } catch {
            errorMessage = MusikKuErrorMessage.indonesianMessage(for: error, fallback: "Kategori ini belum dapat dibuka. Coba lagi nanti.")
        }
    }

    @MainActor
    private func loadMoreCategoryPage() async {
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
            paginationError = "Gagal memuat pilihan berikutnya. Ketuk untuk mencoba ulang."
        }
    }

    private func open(_ item: CatalogItem) {
        if item.canSaveAsTrack {
            playback.play(item.asMusicTrack())
        } else if item.browseID != nil {
            selectedBrowseItem = item
        }
    }
}

private struct ExploreCategoryShelf: View {
    let shelf: CatalogHomeShelf
    let onOpen: (CatalogItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(shelf.title)
                .font(.headline)
            if !shelf.subtitle.isEmpty {
                Text(shelf.subtitle)
                    .font(.caption)
                    .foregroundStyle(MusikKuStyle.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(shelf.items) { item in
                        Button { onOpen(item) } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                ArtworkView(track: item.asMusicTrack(), cornerRadius: 14)
                                    .frame(width: 132, height: 132)
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(2)
                                    .frame(width: 132, alignment: .leading)
                                Text(item.artist.isEmpty ? item.subtitle : item.artist)
                                    .font(.caption)
                                    .foregroundStyle(MusikKuStyle.secondary)
                                    .lineLimit(2)
                                    .frame(width: 132, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct ExploreCategoryTrack: View {
    @EnvironmentObject private var playback: PlaybackManager
    let item: CatalogItem
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 11) {
                ArtworkView(track: item.asMusicTrack(), cornerRadius: 9)
                    .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(item.artist)
                        .font(.caption)
                        .foregroundStyle(MusikKuStyle.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(MusikKuStyle.accent)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if item.canSaveAsTrack {
                Button {
                    playback.enqueue(item.asMusicTrack())
                } label: {
                    Label("Tambah ke antrean", systemImage: "text.badge.plus")
                }
            }
        }
    }
}
