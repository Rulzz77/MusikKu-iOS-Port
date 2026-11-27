import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var library: MusicLibraryStore
    @State private var section: LibrarySection = .playlists
    @State private var showingCreatePlaylist = false
    @State private var playlistName = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Koleksi", selection: $section) {
                    Text("Playlist").tag(LibrarySection.playlists)
                    Text("Disukai").tag(LibrarySection.favorites)
                }
                .pickerStyle(.segmented)

                if section == .playlists {
                    playlistContent
                } else {
                    favoriteContent
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .background(MusikKuStyle.background.ignoresSafeArea())
            .navigationTitle("Koleksi")
            .toolbar {
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
                        TrackLibraryRow(track: track)
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
}

private struct PlaylistDetailView: View {
    @EnvironmentObject private var library: MusicLibraryStore
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
                        Text("Lagu dapat ditambahkan setelah katalog musik terhubung.")
                            .font(.subheadline)
                            .foregroundStyle(MusikKuStyle.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                } else {
                    List {
                        ForEach(playlist.tracks) { track in
                            TrackLibraryRow(track: track)
                                .listRowBackground(MusikKuStyle.surface)
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
            RoundedRectangle(cornerRadius: 10)
                .fill(MusikKuStyle.accent.opacity(0.16))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "music.note")
                        .foregroundStyle(MusikKuStyle.accent)
                }

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
