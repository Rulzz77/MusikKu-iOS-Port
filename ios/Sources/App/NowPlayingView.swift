import SwiftUI

struct MiniPlayerBar: View {
    @EnvironmentObject private var playback: PlaybackManager
    let track: MusicTrack
    let openPlayer: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            Button(action: openPlayer) {
                HStack(spacing: 11) {
                    ArtworkView(track: track, cornerRadius: 9)
                        .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.caption)
                            .foregroundStyle(MusikKuStyle.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Buka pemutar untuk \(track.title)")

            Button {
                playback.togglePlayback()
            } label: {
                Group {
                    Image(
                        systemName: playback.isResolving
                            ? "xmark"
                            : ((playback.isPlaying || playback.isBuffering) ? "pause.fill" : "play.fill")
                    )
                        .font(.title3.bold())
                }
                .frame(width: 42, height: 42)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(playback.isResolving ? "Batalkan pemuatan audio" : ((playback.isPlaying || playback.isBuffering) ? "Jeda" : "Putar"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        }
    }
}

struct NowPlayingView: View {
    @EnvironmentObject private var playback: PlaybackManager
    @EnvironmentObject private var library: MusicLibraryStore
    @State private var isShowingQueue = false
    @State private var isShowingPlaylistPicker = false
    @State private var isShowingLyrics = false
    @State private var isShowingPlayerSettings = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) {
                Group {
                if let track = playback.currentTrack {
                    playerContent(for: track, availableWidth: geometry.size.width, availableHeight: geometry.size.height)
                } else {
                    emptyState(
                        title: "Belum ada lagu",
                        message: "Cari lagu, lalu tekan ikon putar dari Beranda atau Pencarian.",
                        symbol: "music.note"
                    )
                }
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .center)
            }
            .scrollIndicators(.hidden)
            .background(MusikKuStyle.background.ignoresSafeArea())
        }
        .sheet(isPresented: $isShowingQueue) {
            QueueSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingPlaylistPicker) {
            if let track = playback.currentTrack {
                PlaylistPickerSheet(track: track)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $isShowingLyrics) {
            if let track = playback.currentTrack {
                LyricsSheet(track: track)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $isShowingPlayerSettings) {
            PlayerSettingsView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func playerContent(for track: MusicTrack, availableWidth: CGFloat, availableHeight: CGFloat) -> some View {
        let artworkSide = min(min(max(availableWidth - 48, 160), 320), max(160, availableHeight * 0.31))

        return VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("SEDANG DIPUTAR")
                        .font(.caption.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(MusikKuStyle.secondary)
                    Text("MusikKu Player")
                        .font(.headline)
                }

                Spacer()

                Button {
                    isShowingPlayerSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .frame(width: 42, height: 42)
                        .background(MusikKuStyle.surface, in: Circle())
                }
                .accessibilityLabel("Pengaturan pemutar")

                Button {
                    isShowingQueue = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.title3)
                        .frame(width: 42, height: 42)
                        .background(MusikKuStyle.surface, in: Circle())
                }
                .accessibilityLabel("Buka antrean lagu")
            }
             .padding(.top, 8)

            ArtworkView(track: track, cornerRadius: 22)
                .frame(width: artworkSide, height: artworkSide)
                .frame(maxWidth: .infinity)
                .shadow(color: .black.opacity(0.35), radius: 24, y: 12)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(track.title)
                        .font(.title2.bold())
                        .lineLimit(2)
                    Text(track.artist)
                        .font(.subheadline)
                        .foregroundStyle(MusikKuStyle.secondary)
                    if let source = playback.resolvedStreamInfo {
                        Text("Sumber: \(source)")
                            .font(.caption2)
                            .foregroundStyle(MusikKuStyle.secondary)
                            .lineLimit(1)
                    }
                    if let album = track.album, !album.isEmpty {
                        Text(album)
                            .font(.caption)
                            .foregroundStyle(MusikKuStyle.secondary)
                            .lineLimit(1)
                    }
                    if let status = playback.playbackStatusMessage, playback.errorMessage == nil {
                        Text(status)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(playback.isResolving || playback.isBuffering ? MusikKuStyle.accent : MusikKuStyle.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)

                Button {
                    library.toggleFavorite(track)
                } label: {
                    Image(systemName: library.isFavorite(track) ? "heart.fill" : "heart")
                        .font(.title2)
                        .foregroundStyle(library.isFavorite(track) ? .pink : MusikKuStyle.secondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(library.isFavorite(track) ? "Hapus dari lagu disukai" : "Tambahkan ke lagu disukai")
            }

            if playback.isResolving || playback.isBuffering {
                HStack(spacing: 9) {
                    ProgressView().tint(MusikKuStyle.accent)
                    Text(playback.isResolving ? "Mengambil stream audio…" : "Memuat audio…")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MusikKuStyle.secondary)
                    Spacer()
                }
            }

            VStack(spacing: 5) {
                Slider(
                    value: Binding(
                        get: { playback.position },
                        set: { playback.seek(to: $0) }
                    ),
                    in: 0...max(playback.duration, 1)
                )
                .disabled(playback.duration <= 0 || playback.isResolving)

                HStack {
                    Text(Self.time(playback.position))
                    Spacer()
                    Text(Self.time(playback.duration))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(MusikKuStyle.secondary)
            }

            HStack(spacing: 0) {
                Button {
                    playback.toggleShuffle()
                } label: {
                    Image(systemName: "shuffle")
                        .foregroundStyle(playback.isShuffleEnabled ? MusikKuStyle.accent : MusikKuStyle.secondary)
                        .frame(maxWidth: .infinity)
                }
                .accessibilityLabel("Acak lagu")

                Button {
                    playback.playPrevious()
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                }
                .accessibilityLabel("Lagu sebelumnya")
                .disabled(playback.isResolving)

                Button {
                    playback.togglePlayback()
                } label: {
                    Image(
                        systemName: playback.isResolving
                            ? "xmark"
                            : ((playback.isPlaying || playback.isBuffering) ? "pause.fill" : "play.fill")
                    )
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 66, height: 66)
                        .background(MusikKuStyle.accent.gradient, in: Circle())
                }
                .accessibilityLabel(playback.isResolving ? "Batalkan pemuatan audio" : ((playback.isPlaying || playback.isBuffering) ? "Jeda" : "Putar"))

                Button {
                    playback.playNext()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                }
                .accessibilityLabel("Lagu berikutnya")
                .disabled(playback.isResolving)

                Button {
                    playback.toggleRepeat()
                } label: {
                    Image(systemName: playback.repeatMode == .one ? "repeat.1" : "repeat")
                        .foregroundStyle(playback.repeatMode == .off ? MusikKuStyle.secondary : MusikKuStyle.accent)
                        .frame(maxWidth: .infinity)
                }
                .accessibilityLabel(playback.repeatMode.title)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)

            HStack(spacing: 14) {
                Button {
                    isShowingPlaylistPicker = true
                } label: {
                    Label("Playlist", systemImage: "text.badge.plus")
                        .font(.subheadline.weight(.semibold))
                }

                Spacer(minLength: 0)

                Button {
                    isShowingLyrics = true
                } label: {
                    Label("Lirik", systemImage: "quote.bubble")
                        .font(.subheadline.weight(.semibold))
                }

                Spacer(minLength: 0)

                Button {
                    isShowingQueue = true
                } label: {
                    Label("Antrean (\(playback.queue.count))", systemImage: "list.bullet")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .foregroundStyle(MusikKuStyle.secondary)

            if let error = playback.errorMessage {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Pemutaran belum berhasil", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(MusikKuStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        playback.togglePlayback()
                    } label: {
                        Label("Coba putar lagi", systemImage: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(MusikKuStyle.accent.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MusikKuStyle.surface, in: RoundedRectangle(cornerRadius: 16))
            }

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 20)
    }

    private func emptyState(title: String, message: String, symbol: String) -> some View {
        VStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 42))
                .foregroundStyle(MusikKuStyle.accent)
            Text(title).font(.title3.bold())
            Text(message)
                .font(.subheadline)
                .foregroundStyle(MusikKuStyle.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
    }

    private static func time(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let whole = Int(seconds)
        return "\(whole / 60):\(String(format: "%02d", whole % 60))"
    }
}

struct ArtworkView: View {
    let track: MusicTrack
    var cornerRadius: CGFloat = 14

    var body: some View {
        Group {
            if let artworkURL = track.artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        placeholder
                            .overlay {
                                ProgressView()
                                    .tint(MusikKuStyle.accent)
                            }
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .accessibilityLabel("Sampul album \(track.album ?? track.title)")
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [MusikKuStyle.accent.opacity(0.6), Color(red: 0.15, green: 0.12, blue: 0.24)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: "waveform")
                    .font(.system(size: 46, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
    }
}

private struct QueueSheet: View {
    @EnvironmentObject private var playback: PlaybackManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingClearConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if playback.queue.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "text.badge.plus")
                            .font(.system(size: 34))
                            .foregroundStyle(MusikKuStyle.accent)
                        Text("Antrean kosong").font(.headline)
                        Text("Lagu berikutnya akan muncul di sini.")
                            .font(.subheadline)
                            .foregroundStyle(MusikKuStyle.secondary)
                    }
                } else {
                    List {
                        ForEach(Array(playback.queue.enumerated()), id: \.offset) { index, track in
                            HStack(spacing: 11) {
                                Button {
                                    playback.playQueue(playback.queue, startingAt: index)
                                } label: {
                                    HStack(spacing: 11) {
                                        ArtworkView(track: track, cornerRadius: 8)
                                            .frame(width: 42, height: 42)

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
                                        if index == playback.currentQueueTrackIndex {
                                            Image(systemName: "waveform")
                                                .foregroundStyle(MusikKuStyle.accent)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                Button(role: .destructive) {
                                    playback.removeQueueItem(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(MusikKuStyle.secondary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Hapus \(track.title) dari antrean")
                            }
                            .listRowBackground(MusikKuStyle.surface)
                        }
                        .onMove { source, destination in
                            guard let from = source.first else { return }
                            let to = destination > from ? destination - 1 : destination
                            playback.moveQueueItem(from: from, to: to)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(MusikKuStyle.background.ignoresSafeArea())
            .navigationTitle("Antrean lagu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showingClearConfirmation = true
                        } label: {
                            Label("Kosongkan antrean", systemImage: "trash")
                        }
                        .disabled(playback.queue.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Aksi antrean")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Selesai") { dismiss() }
                }
            }
            .confirmationDialog(
                "Kosongkan antrean?",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Kosongkan antrean", role: .destructive) {
                    playback.playQueue([])
                }
                Button("Batal", role: .cancel) {}
            } message: {
                Text("Semua lagu akan dihapus dari antrean dan pemutaran dihentikan.")
            }
        }
    }
}

private struct PlaylistPickerSheet: View {
    @EnvironmentObject private var library: MusicLibraryStore
    @Environment(\.dismiss) private var dismiss
    let track: MusicTrack

    var body: some View {
        NavigationStack {
            Group {
                if library.playlists.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 34))
                            .foregroundStyle(MusikKuStyle.accent)
                        Text("Belum ada playlist").font(.headline)
                        Text("Buat playlist terlebih dahulu dari tab Koleksi.")
                            .font(.subheadline)
                            .foregroundStyle(MusikKuStyle.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                } else {
                    List {
                        ForEach(library.playlists) { playlist in
                            Button {
                                library.add(track, to: playlist.id)
                                dismiss()
                            } label: {
                                HStack {
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
                                    Image(systemName: playlist.tracks.contains(where: { $0.id == track.id }) ? "checkmark.circle.fill" : "plus.circle")
                                        .foregroundStyle(MusikKuStyle.accent)
                                }
                            }
                            .disabled(playlist.tracks.contains(where: { $0.id == track.id }))
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
