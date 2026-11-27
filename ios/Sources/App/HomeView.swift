import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var playback: PlaybackManager
    @EnvironmentObject private var library: MusicLibraryStore
    @State private var homeShelves: [CatalogHomeShelf] = []
    @State private var isLoadingHome = false
    @State private var homeErrorMessage: String?
    @State private var didLoadHome = false
    let onExplore: () -> Void

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

                    homeFeedContent
                    playerCard

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
                ForEach(homeShelves) { shelf in
                    CatalogHomeShelfSection(shelf: shelf)
                }

                Text("Katalog menampilkan metadata dan sampul. Pemutaran lagu akan aktif setelah resolver audio iOS terhubung.")
                    .font(.caption)
                    .foregroundStyle(MusikKuStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @MainActor
    private func loadHomeFeed() async {
        guard !didLoadHome else { return }
        didLoadHome = true
        isLoadingHome = true
        homeErrorMessage = nil
        defer { isLoadingHome = false }

        do {
            homeShelves = try await MusicCatalogService.shared.homeFeed()
            if homeShelves.isEmpty {
                homeErrorMessage = "Belum ada rekomendasi yang dikirim katalog untuk sesi ini."
            }
        } catch {
            homeErrorMessage = error.localizedDescription
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

            Image(systemName: "person.crop.circle")
                .font(.system(size: 25))
                .foregroundStyle(MusikKuStyle.secondary)
                .accessibilityLabel("Profil")
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

            Text("Fondasi aplikasi sudah siap. Katalog perlu dihubungkan ke penyedia musik yang mengizinkan streaming di aplikasi iOS.")
                .font(.subheadline)
                .foregroundStyle(MusikKuStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onExplore) {
                Label("Lihat status pencarian", systemImage: "arrow.right")
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

    private var playerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("PEMUTAR", systemImage: "waveform")
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(MusikKuStyle.secondary)

                Spacer()

                Text(playback.isPlaying ? "SEDANG DIPUTAR" : "SIAP")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(playback.isPlaying ? .green : MusikKuStyle.secondary)
            }

            HStack(spacing: 13) {
                RoundedRectangle(cornerRadius: 15)
                    .fill(MusikKuStyle.accent.opacity(0.22).gradient)
                    .frame(width: 66, height: 66)
                    .overlay {
                        Image(systemName: "waveform")
                            .font(.system(size: 25, weight: .medium))
                            .foregroundStyle(MusikKuStyle.accent)
                    }

                VStack(alignment: .leading, spacing: 5) {
                    Text(playback.currentTrack?.title ?? "Belum ada lagu")
                        .font(.headline)
                        .lineLimit(1)
                    Text(playback.currentTrack?.artist ?? "Pilih lagu dari katalog saat tersedia")
                        .font(.subheadline)
                        .foregroundStyle(MusikKuStyle.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            if playback.currentTrack != nil {
                Slider(
                    value: Binding(
                        get: { playback.position },
                        set: { playback.seek(to: $0) }
                    ),
                    in: 0...max(playback.duration, 1)
                )

                HStack {
                    Text(Self.time(playback.position))
                    Spacer()
                    Text(Self.time(playback.duration))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(MusikKuStyle.secondary)
            }

            HStack(spacing: 30) {
                Button {
                    playback.playPrevious()
                } label: {
                    Image(systemName: "backward.end.fill").font(.title3)
                }
                .disabled(playback.currentTrack == nil)

                Button {
                    playback.togglePlayback()
                } label: {
                    Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(MusikKuStyle.accent.gradient, in: Circle())
                }
                .disabled(playback.currentTrack == nil)
                .accessibilityLabel(playback.isPlaying ? "Jeda" : "Putar")

                Button {
                    playback.playNext()
                } label: {
                    Image(systemName: "forward.end.fill").font(.title3)
                }
                .disabled(playback.currentTrack == nil)
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.plain)

            if let error = playback.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(17)
        .background(MusikKuStyle.surface, in: RoundedRectangle(cornerRadius: 20))
    }

    private static func time(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let whole = Int(seconds)
        return "\(whole / 60):\(String(format: "%02d", whole % 60))"
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
                        CatalogHomeItemCard(item: item)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct CatalogHomeItemCard: View {
    let item: CatalogItem

    var body: some View {
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
