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
            .onChange(of: playlistLink) { _ in
                result = nil
                errorMessage = nil
                savedMessage = nil
            }
        }
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
                resultMetric(title: "Cocok", value: result.matchedTracks.count, color: MusikKuStyle.accent)
                resultMetric(title: "Tidak cocok", value: result.unmatchedEntries.count, color: MusikKuStyle.secondary)
                resultMetric(title: "Gagal cek", value: result.failedEntries.count, color: .orange)
            }

            Text("Pencocokan mensyaratkan judul, artis utama, dan durasi yang dekat. Hasil yang meragukan tidak akan otomatis dimasukkan.")
                .font(.caption)
                .foregroundStyle(MusikKuStyle.secondary)

            if !result.unmatchedEntries.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Belum ditemukan")
                        .font(.subheadline.weight(.semibold))
                    ForEach(result.unmatchedEntries.prefix(8)) { entry in
                        sourceTrackRow(entry.source, note: "Belum ada kecocokan yang cukup aman")
                    }
                    if result.unmatchedEntries.count > 8 {
                        Text("Dan \(result.unmatchedEntries.count - 8) lagu lainnya.")
                            .font(.caption)
                            .foregroundStyle(MusikKuStyle.secondary)
                    }
                }
            }

            if !result.failedEntries.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Pemeriksaan gagal")
                        .font(.subheadline.weight(.semibold))
                    ForEach(result.failedEntries.prefix(5)) { entry in
                        sourceTrackRow(entry.source, note: "Katalog tidak dapat diperiksa")
                    }
                    Text("Lagu ini belum dinyatakan tidak tersedia; pencariannya gagal karena gangguan jaringan atau layanan.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            if let savedMessage {
                Label(savedMessage, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Button {
                    let count = library.importPlaylist(result.title, tracks: result.matchedTracks)
                    if count > 0 {
                        savedMessage = "\(count) lagu disimpan ke Koleksi sebagai playlist lokal."
                    } else {
                        savedMessage = "Belum ada lagu yang dapat disimpan."
                    }
                } label: {
                    Text("Simpan \(result.matchedTracks.count) lagu ke Koleksi")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            result.matchedTracks.isEmpty ? MusikKuStyle.secondary : MusikKuStyle.accent,
                            in: RoundedRectangle(cornerRadius: 13)
                        )
                }
                .buttonStyle(.plain)
                .disabled(result.matchedTracks.isEmpty)
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

    private func sourceTrackRow(_ source: SpotifySourceTrack, note: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(source.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text("\(source.artistText.isEmpty ? "Artis tidak diketahui" : source.artistText) • \(note)")
                .font(.system(size: 10))
                .foregroundStyle(MusikKuStyle.secondary)
                .lineLimit(2)
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
