import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var library: MusicLibraryStore
    @State private var query = ""
    @State private var selectedFilter: CatalogSearchFilter = .all
    @State private var results: [CatalogItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasSearched = false
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
                            errorMessage = nil
                            hasSearched = false
                        }
                        .font(.subheadline)
                    }
                }
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

                ForEach(results) { item in
                    CatalogResultRow(
                        item: item,
                        isSaved: item.canSaveAsTrack && library.isFavorite(item.asMusicTrack()),
                        onSave: {
                            guard item.canSaveAsTrack else { return }
                            library.toggleFavorite(item.asMusicTrack())
                        }
                    )
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                }

                Text("Hasil pencarian menampilkan metadata katalog. URL audio belum dihubungkan ke pemutar iOS.")
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
        } else {
            statusView(
                symbol: "sparkle.magnifyingglass",
                title: "Temukan musik",
                message: "Cari lagu, artis, album, atau playlist dari katalog yang digunakan MusikKu Android.",
                action: nil
            )
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
        hasSearched = true
        defer { isLoading = false }

        do {
            results = try await MusicCatalogService.shared.search(
                query: trimmed,
                filter: selectedFilter
            )
        } catch {
            results = []
            errorMessage = error.localizedDescription
        }
    }
}

private struct CatalogResultRow: View {
    let item: CatalogItem
    let isSaved: Bool
    let onSave: () -> Void

    var body: some View {
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

            Spacer(minLength: 0)

            if item.canSaveAsTrack {
                Button(action: onSave) {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundStyle(isSaved ? .pink : MusikKuStyle.secondary)
                        .frame(width: 38, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSaved ? "Hapus dari lagu disukai" : "Simpan ke lagu disukai")
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MusikKuStyle.secondary.opacity(0.7))
                    .padding(.horizontal, 7)
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
