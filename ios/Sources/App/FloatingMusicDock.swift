import SwiftUI

enum AppMainTab: String, CaseIterable, Identifiable {
    case home
    case explore
    case library

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Beranda"
        case .explore: return "Explore"
        case .library: return "Koleksi"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .explore: return "safari.fill"
        case .library: return "square.stack.3d.up.fill"
        }
    }
}

/// One floating glass surface for the transport controls and the three main tabs.
struct FloatingMusicDock: View {
    @EnvironmentObject private var playback: PlaybackManager

    let selectedTab: AppMainTab
    let onSelectTab: (AppMainTab) -> Void
    let onOpenPlayer: () -> Void

    var body: some View {
        VStack(spacing: 9) {
            if let track = playback.currentTrack {
                nowPlayingAccessory(track)
                Rectangle()
                    .fill(.white.opacity(0.09))
                    .frame(height: 1)
                    .padding(.horizontal, 5)
            }

            HStack(spacing: 5) {
                ForEach(AppMainTab.allCases) { tab in
                    Button {
                        onSelectTab(tab)
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: tab.symbol)
                                .font(.system(size: 17, weight: .semibold))
                                .frame(height: 20)
                            Text(tab.title)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(selectedTab == tab ? .white : MusikKuStyle.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if selectedTab == tab {
                                RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    .fill(MusikKuStyle.accent.opacity(0.25))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                                            .stroke(MusikKuStyle.accent.opacity(0.22), lineWidth: 1)
                                    }
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.title)
                    .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 7)
        .frame(maxWidth: 560)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 29, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 29, style: .continuous)
                .stroke(.white.opacity(0.13), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 22, y: 9)
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 5)
        .frame(maxWidth: .infinity)
    }

    private func nowPlayingAccessory(_ track: MusicTrack) -> some View {
        HStack(spacing: 10) {
            Button(action: onOpenPlayer) {
                HStack(spacing: 10) {
                    ArtworkView(track: track, cornerRadius: 10)
                        .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                        Text(track.artist)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundStyle(MusikKuStyle.secondary)
                        if playback.isResolving || playback.isBuffering {
                            Text(playback.isResolving ? "Mengambil stream…" : "Memuat audio…")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(MusikKuStyle.accent)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Buka pemutar \(track.title)")

            Button {
                playback.togglePlayback()
            } label: {
                Image(systemName: playback.isResolving ? "xmark" : (playback.isPlaying ? "pause.fill" : "play.fill"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 38, height: 38)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(playback.isResolving ? "Batalkan pemuatan" : (playback.isPlaying ? "Jeda" : "Putar"))

            Button {
                playback.playNext()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MusikKuStyle.secondary)
                    .frame(width: 32, height: 38)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Lagu berikutnya")
        }
        .padding(.horizontal, 5)
    }
}
