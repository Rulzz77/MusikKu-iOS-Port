import SwiftUI

struct SpotifyPlaylistImportView: View {
    @EnvironmentObject private var library: MusicLibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var playlistLink = ""
    @State private var isImporting = false
    @State private var progressText = ""
    @State private var errorMessage: String?
    @State private var result: SpotifyPlaylistImportResult?
    @State private var savedMessage: String?
    @State private var editingEntry: SpotifyPlaylistImportEntry?
    @State private var manualMatches: [String: MusicTrack] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        Label("Import tanpa login", systemImage: "person.crop.circle.badge.checkmark")
                            .font(.headline)
                        Text("Tempel tautan playlist Spotify publik. MusikKu akan mencari kecocokan lagu di katalog, lalu menyimpan hasilnya sebagai playlist lokal di perangkat ini.")
                            .font(.subheadline)
                            .foregroundStyle(MusikKuStyle.secondary)
                    }

                    VStack(spacing: 10) {
                        TextField("https://open.spotify.com/playlist/…", text: $playlistLink)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .padding(13)
                            .background(MusikKuStyle.surface, in: RoundedRectangle(cornerRadius: 13))

                        Button {
                            Task { await startImport() }
                        } label: {
                            HStack(spacing: 8) {
                                if isImporting {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "arrow.down.doc")
                                }
                                Text(isImporting ? "Memproses playlist…" : "Cocokkan lagu")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(MusikKuStyle.accent.gradient, in: RoundedRectangle(cornerRadius: 13))
                        }
                        .buttonStyle(.plain)
                        .disabled(isImporting || playlistLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if isImporting {
                        HStack(spacing: 10) {
                            ProgressView().tint(MusikKuStyle.accent)
                            Text(progressText.isEmpty ? "Memuat metadata Spotify…" : progressText)
                                .font(.caption)
                                .foregroundStyle(MusikKuStyle.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "wifi.exclamationmark")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let result {
                        resultSection(result)
                    }
                }
                .padding(18)
            }
            .background(MusikKuStyle.background.ignoresSafeArea())
            .navigationTitle("Import Spotify")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Tutup") { dismiss() }
                        .disabled(isImporting)
                }
            }
            .interactiveDismissDisabled(isImporting)
            .sheet(item: $editingEntry) { entry in
                SpotifyManualMatchSheet(source: entry.source) { track in
                    manualMatches[entry.id] = track
                    savedMessage = nil
                    editingEntry = nil
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .onChange(of: playlistLink) { _ in
                result = nil
                errorMessage = nil
                savedMessage = nil
                manualMatches = [:]
            }
        }
    }

    private var tracksToSave: [MusicTrack] {
        guard let result else { return [] }
        var seen = Set<String>()
        return result.entries.compactMap { entry in
            guard let track = manualMatches[entry.id] ?? entry.matchedTrack else { return nil }
            let id = track.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty, seen.insert(id).inserted else { return nil }
            return track
        }
    }

    private func needsManualMatch(_ entry: SpotifyPlaylistImportEntry) -> Bool {
        entry.matchedTrack == nil && manualMatches[entry.id] == nil
    }

    private var manuallyMatchedEntries: [SpotifyPlaylistImportEntry] {
        guard let result else { return [] }
        return result.entries.filter { manualMatches[$0.id] != nil }
    }

    @ViewBuilder
    private func resultSection(_ result: SpotifyPlaylistImportResult) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 12) {
                if let artworkURL = result.artworkURL {
                    AsyncImage(url: artworkURL) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            playlistArtworkPlaceholder
                        }
                    }
                    .frame(width: 68, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    playlistArtworkPlaceholder
                        .frame(width: 68, height: 68)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .font(.headline)
                        .lineLimit(2)
                    Text("\(result.entries.count) lagu dibaca dari Spotify")
                        .font(.caption)
                        .foregroundStyle(MusikKuStyle.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(MusikKuStyle.surface, in: RoundedRectangle(cornerRadius: 15))

            HStack(spacing: 8) {
                resultMetric(title: "Cocok", value: tracksToSave.count, color: MusikKuStyle.accent)
                resultMetric(title: "Tidak cocok", value: result.unmatchedEntries.filter(needsManualMatch).count, color: MusikKuStyle.secondary)
                resultMetric(title: "Gagal cek", value: result.failedEntries.filter(needsManualMatch).count, color: .orange)
            }

            Text("Pencocokan mensyaratkan judul, artis utama, dan durasi yang dekat. Hasil yang meragukan tidak akan otomatis dimasukkan.")
                .font(.caption)
                .foregroundStyle(MusikKuStyle.secondary)

            if !result.unmatchedEntries.filter(needsManualMatch).isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Belum ditemukan")
                        .font(.subheadline.weight(.semibold))
                    ForEach(result.unmatchedEntries.filter(needsManualMatch)) { entry in
                        sourceTrackRow(entry, note: "Belum ada kecocokan yang cukup aman")
                    }
                }
            }

            if !result.failedEntries.filter(needsManualMatch).isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Pemeriksaan gagal")
                        .font(.subheadline.weight(.semibold))
                    ForEach(result.failedEntries.filter(needsManualMatch)) { entry in
                        sourceTrackRow(
                            entry,
                            note: entry.lookupFailure ?? "Katalog tidak dapat diperiksa"
                        )
                    }
                    Text("Lagu ini belum dinyatakan tidak tersedia; pencariannya gagal karena gangguan jaringan atau layanan.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            if !manuallyMatchedEntries.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Dipilih manual")
                        .font(.subheadline.weight(.semibold))
                    ForEach(manuallyMatchedEntries) { entry in
                        sourceTrackRow(entry, note: "Pengganti dipilih oleh kamu")
                    }
                }
            }

            if let savedMessage {
                Label(savedMessage, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Button {
                    let count = library.importPlaylist(result.title, tracks: tracksToSave)
                    if count > 0 {
                        savedMessage = "\(count) lagu disimpan ke Koleksi sebagai playlist lokal."
                    } else {
                        savedMessage = "Belum ada lagu yang dapat disimpan."
                    }
                } label: {
                    Text("Simpan \(tracksToSave.count) lagu ke Koleksi")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            tracksToSave.isEmpty ? MusikKuStyle.secondary : MusikKuStyle.accent,
                            in: RoundedRectangle(cornerRadius: 13)
                        )
                }
                .buttonStyle(.plain)
                .disabled(tracksToSave.isEmpty)
            }

            Button("Selesai") { dismiss() }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(14)
        .background(MusikKuStyle.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 18))
    }

    private var playlistArtworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(MusikKuStyle.accent.opacity(0.16))
            .overlay {
                Image(systemName: "music.note.list")
                    .font(.title2)
                    .foregroundStyle(MusikKuStyle.accent)
            }
    }

    private func sourceTrackRow(_ entry: SpotifyPlaylistImportEntry, note: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.source.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text("\(entry.source.artistText.isEmpty ? "Artis tidak diketahui" : entry.source.artistText) • \(note)")
                        .font(.system(size: 10))
                        .foregroundStyle(MusikKuStyle.secondary)
                        .lineLimit(2)
                    if let selected = manualMatches[entry.id] {
                        Text("Pilihan manual: \(selected.title) — \(selected.artist)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(MusikKuStyle.accent)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 4)
                Button {
                    editingEntry = entry
                } label: {
                    Text(manualMatches[entry.id] == nil ? "Cari" : "Ganti")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(MusikKuStyle.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 5)
    }

    private func resultMetric(title: String, value: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(MusikKuStyle.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(MusikKuStyle.background, in: RoundedRectangle(cornerRadius: 12))
    }

    @MainActor
    private func startImport() async {
        isImporting = true
        progressText = "Memuat metadata Spotify…"
        errorMessage = nil
        result = nil
        savedMessage = nil
        manualMatches = [:]
        defer { isImporting = false }

        do {
            result = try await SpotifyPlaylistImportService.shared.importPlaylist(from: playlistLink) { completed, total in
                progressText = "Mencocokkan \(completed) dari \(total) lagu…"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}


private struct SpotifyManualMatchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query: String
    @State private var results: [CatalogItem] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    let source: SpotifySourceTrack
    let onSelect: (MusicTrack) -> Void

    init(source: SpotifySourceTrack, onSelect: @escaping (MusicTrack) -> Void) {
        self.source = source
        self.onSelect = onSelect
        _query = State(initialValue: "\(source.title) \(source.leadArtist)")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    TextField("Judul lagu atau artis", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { Task { await search() } }

                    Button {
                        Task { await search() }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.headline)
                            .frame(width: 42, height: 42)
                            .background(MusikKuStyle.accent, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)
                    }
                    .disabled(isSearching || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(12)
                .background(MusikKuStyle.surface, in: RoundedRectangle(cornerRadius: 13))

                if isSearching {
                    ProgressView("Mencari lagu…")
                        .tint(MusikKuStyle.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    VStack(spacing: 8) {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                        Button("Coba lagi") { Task { await search() } }
                            .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if results.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "music.note.magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundStyle(MusikKuStyle.accent)
                        Text("Pilih pengganti lagu")
                            .font(.headline)
                        Text("Cari lagu katalog yang paling sesuai dengan judul Spotify.")
                            .font(.caption)
                            .foregroundStyle(MusikKuStyle.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(results) { item in
                                Button {
                                    onSelect(item.asMusicTrack())
                                    dismiss()
                                } label: {
                                    HStack(spacing: 11) {
                                        AsyncImage(url: item.artworkURL) { phase in
                                            if let image = phase.image {
                                                image.resizable().scaledToFill()
                                            } else {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(MusikKuStyle.accent.opacity(0.15))
                                                    .overlay {
                                                        Image(systemName: "music.note")
                                                            .foregroundStyle(MusikKuStyle.accent)
                                                    }
                                            }
                                        }
                                        .frame(width: 48, height: 48)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.title)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)
                                            Text(item.subtitle.isEmpty ? item.artist : item.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(MusikKuStyle.secondary)
                                                .lineLimit(2)
                                        }
                                        Spacer(minLength: 0)
                                        Image(systemName: "checkmark.circle")
                                            .foregroundStyle(MusikKuStyle.accent)
                                    }
                                    .padding(9)
                                    .background(MusikKuStyle.surface, in: RoundedRectangle(cornerRadius: 12))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(MusikKuStyle.background.ignoresSafeArea())
            .navigationTitle("Pilih lagu pengganti")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Batal") { dismiss() }
                }
            }
            .task {
                if results.isEmpty { await search() }
            }
        }
    }

    @MainActor
    private func search() async {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else { return }
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        do {
            let page = try await MusicCatalogService.shared.searchPage(query: cleanQuery, filter: .songs)
            results = page.items.filter { $0.kind == .song && $0.canSaveAsTrack }
            if results.isEmpty {
                errorMessage = "Tidak ada lagu yang cocok dengan pencarian ini."
            }
        } catch {
            results = []
            errorMessage = error.localizedDescription
        }
    }
}
