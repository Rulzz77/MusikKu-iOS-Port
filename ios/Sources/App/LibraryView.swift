import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var library: MusicLibraryStore
    @EnvironmentObject private var playback: PlaybackManager
    @State private var section: LibrarySection = .playlists
    @State private var showingCreatePlaylist = false
    @State private var showingCreateSmartPlaylist = false
    @State private var playlistName = ""
    let onSearch: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Koleksi", selection: $section) {
                    Text("Playlist").tag(LibrarySection.playlists)
                    Text("Disukai").tag(LibrarySection.favorites)
                    Text("Riwayat").tag(LibrarySection.history)
                    Text("Mix").tag(LibrarySection.smartMix)
                }
                .pickerStyle(.segmented)

                switch section {
                case .playlists:
                    playlistContent
                case .favorites:
                    favoriteContent
                case .history:
                    historyContent
                case .smartMix:
                    smartMixContent
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .background(MusikKuStyle.background.ignoresSafeArea())
            .navigationTitle("Koleksi")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onSearch) {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Cari musik")
                }
                if section == .playlists {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            playlistName = ""
                            showingCreatePlaylist = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Buat playlist")
                    }
                } else if section == .smartMix {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingCreateSmartPlaylist = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Buat Mix Cerdas")
                    }
                }
            }
            .alert("Buat playlist baru", isPresented: $showingCreatePlaylist) {
                TextField("Nama playlist", text: $playlistName)
                Button("Batal", role: .cancel) {
                    playlistName = ""
                }
                Button("Buat") {
                    _ = library.createPlaylist(playlistName)
                    playlistName = ""
                }
            } message: {
                Text("Playlist disimpan secara lokal di perangkat ini.")
            }
            .sheet(isPresented: $showingCreateSmartPlaylist) {
                SmartPlaylistEditorSheet { name, artist, minimumPlays, sort in
                    _ = library.createSmartPlaylist(
                        name: name,
                        artistContains: artist,
                        minimumPlays: minimumPlays,
                        sort: sort
                    )
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    @ViewBuilder
    private var playlistContent: some View {
        if library.playlists.isEmpty {
            emptyState(
                symbol: "music.note.list",
                title: "Belum ada playlist",
                message: "Buat playlist untuk mulai merapikan koleksi musikmu.",
                actionTitle: "Buat playlist"
            ) {
                playlistName = ""
                showingCreatePlaylist = true
            }
        } else {
            List {
                ForEach(library.playlists) { playlist in
                    NavigationLink {
                        PlaylistDetailView(playlistID: playlist.id)
                    } label: {
                        HStack(spacing: 13) {
                            Image(systemName: "music.note.list")
                                .font(.title3)
                                .foregroundStyle(MusikKuStyle.accent)
                                .frame(width: 48, height: 48)
                                .background(MusikKuStyle.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 13))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(playlist.name)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(playlist.tracks.count) lagu")
                                    .font(.caption)
                                    .foregroundStyle(MusikKuStyle.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(MusikKuStyle.surface)
                    .swipeActions {
                        Button(role: .destructive) {
                            library.deletePlaylist(id: playlist.id)
                        } label: {
                            Label("Hapus", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private var favoriteContent: some View {
        if library.favorites.isEmpty {
            emptyState(
                symbol: "heart",
                title: "Belum ada lagu disukai",
                message: "Lagu yang kamu tandai dengan ikon hati akan tersimpan di sini.",
                actionTitle: nil,
                action: nil
            )
        } else {
            List {
                ForEach(library.favorites) { track in
                    HStack(spacing: 12) {
                        Button {
                            playback.play(track)
                        } label: {
                            TrackLibraryRow(track: track)
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: 4)

                        Button {
                            library.toggleFavorite(track)
                        } label: {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.pink)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Hapus dari lagu disukai")
                    }
                    .listRowBackground(MusikKuStyle.surface)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private var historyContent: some View {
        if library.listeningHistory.isEmpty {
            emptyState(
                symbol: "clock.arrow.circlepath",
                title: "Belum ada riwayat",
                message: "Lagu yang kamu putar akan tersimpan di perangkat ini.",
                actionTitle: nil,
                action: nil
            )
        } else {
            List {
                ForEach(library.listeningHistory) { entry in
                    Button {
                        playback.play(entry.track)
                    } label: {
                        HStack(spacing: 12) {
                            TrackLibraryRow(track: entry.track)
                            Spacer(minLength: 4)
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("\(entry.playCount)×")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(MusikKuStyle.accent)
                                Text(entry.lastPlayedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 9))
                                    .foregroundStyle(MusikKuStyle.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(MusikKuStyle.surface)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private var smartMixContent: some View {
        if library.smartPlaylists.isEmpty {
            emptyState(
                symbol: "sparkles",
                title: "Belum ada Mix Cerdas",
                message: "Buat aturan sederhana agar MusikKu menyusun playlist dari lagu yang sering kamu dengarkan.",
                actionTitle: "Buat Mix Cerdas"
            ) {
                showingCreateSmartPlaylist = true
            }
        } else {
            List {
                ForEach(library.smartPlaylists) { rule in
                    let tracks = library.tracks(for: rule)
                    Button {
                        guard !tracks.isEmpty else { return }
                        playback.playQueue(tracks)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "waveform.path")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(MusikKuStyle.accent)
                                .frame(width: 48, height: 48)
                                .background(MusikKuStyle.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 13))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(rule.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(smartPlaylistDescription(rule, trackCount: tracks.count))
                                    .font(.caption)
                                    .foregroundStyle(MusikKuStyle.secondary)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundStyle(tracks.isEmpty ? MusikKuStyle.secondary : MusikKuStyle.accent)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(tracks.isEmpty)
                    .listRowBackground(MusikKuStyle.surface)
                    .swipeActions {
                        Button(role: .destructive) {
                            library.deleteSmartPlaylist(id: rule.id)
                        } label: {
                            Label("Hapus", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func smartPlaylistDescription(_ rule: MusicSmartPlaylistRule, trackCount: Int) -> String {
        let artistText = rule.artistContains.isEmpty ? "Semua artis" : "Artis: \(rule.artistContains)"
        return "\(trackCount) lagu • \(artistText) • Minimal \(rule.minimumPlays)× • \(rule.sort.title)"
    }

    private func emptyState(
        symbol: String,
        title: String,
        message: String,
        actionTitle: String?,
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

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(MusikKuStyle.accent.opacity(0.2), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private enum LibrarySection: Hashable {
    case playlists
    case favorites
    case history
    case smartMix
}


private struct SmartPlaylistEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var artist = ""
    @State private var minimumPlays = 2
    @State private var sort: MusicSmartPlaylistSort = .mostPlayed

    let onSave: (String, String, Int, MusicSmartPlaylistSort) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Nama Mix") {
                    TextField("Contoh: Lagu yang paling sering didengar", text: $name)
                        .textInputAutocapitalization(.sentences)
                }

                Section("Aturan") {
                    TextField("Filter artis (opsional)", text: $artist)
                        .textInputAutocapitalization(.words)
                    Stepper("Minimal diputar: \(minimumPlays)×", value: $minimumPlays, in: 1...50)
                    Picker("Urutan", selection: $sort) {
                        ForEach(MusicSmartPlaylistSort.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                }

                Section {
                    Text("Hasil Mix akan berubah otomatis mengikuti riwayat pemutaran lokal di perangkat ini.")
                        .font(.footnote)
                        .foregroundStyle(MusikKuStyle.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(MusikKuStyle.background)
            .navigationTitle("Mix Cerdas Baru")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") {
                        onSave(name, artist, minimumPlays, sort)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct PlaylistDetailView: View {
    @EnvironmentObject private var library: MusicLibraryStore
    @EnvironmentObject private var playback: PlaybackManager
    let playlistID: UUID

    private var playlist: MusicPlaylist? {
        library.playlists.first { $0.id == playlistID }
    }

    var body: some View {
        Group {
            if let playlist {
                if playlist.tracks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .font(.system(size: 36))
                            .foregroundStyle(MusikKuStyle.accent)
                        Text("Playlist masih kosong").font(.headline)
                        Text("Tambahkan lagu dari hasil pencarian, lalu tekan lagu untuk memutarnya.")
                            .font(.subheadline)
                            .foregroundStyle(MusikKuStyle.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                } else {
                    List {
                        ForEach(Array(playlist.tracks.enumerated()), id: \.offset) { index, track in
                            Button {
                                playback.playQueue(playlist.tracks, startingAt: index)
                            } label: {
                                TrackLibraryRow(track: track)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(MusikKuStyle.surface)
                            .swipeActions {
                                Button(role: .destructive) {
                                    library.remove(track, from: playlistID)
                                } label: {
                                    Label("Hapus", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            } else {
                Text("Playlist tidak ditemukan.")
                    .foregroundStyle(MusikKuStyle.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MusikKuStyle.background.ignoresSafeArea())
        .navigationTitle(playlist?.name ?? "Playlist")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TrackLibraryRow: View {
    let track: MusicTrack

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(track: track, cornerRadius: 10)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(track.artist)
                    .font(.caption)
                    .foregroundStyle(MusikKuStyle.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
    }
}
