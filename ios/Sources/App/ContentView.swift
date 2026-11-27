import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var playback: PlaybackManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("MusikKu")
                            .font(.largeTitle.bold())
                        Text("Musik kamu, cara dengarmu.")
                            .foregroundStyle(.secondary)
                    }

                    playerCard

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Fondasi iOS sudah disiapkan", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Aplikasi ini belum terhubung ke katalog musik. Hubungkan penyedia streaming yang mengizinkan penggunaan di aplikasi iOS sebelum mengaktifkan pencarian dan pemutaran lagu.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tahap berikutnya")
                            .font(.headline)
                        Label("Sambungkan katalog resmi", systemImage: "music.note.list")
                        Label("Tambahkan antrean dan playlist", systemImage: "text.badge.plus")
                        Label("Integrasikan lirik", systemImage: "quote.bubble")
                        Label("Uji background audio di iPhone", systemImage: "lock.iphone")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .background(Color(red: 0.055, green: 0.055, blue: 0.08))
            .navigationBarHidden(true)
        }
        .tint(Color(red: 0.66, green: 0.48, blue: 1.0))
    }

    private var playerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("NOW PLAYING")
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.purple.opacity(0.25).gradient)
                    .frame(width: 76, height: 76)
                    .overlay {
                        Image(systemName: "waveform")
                            .font(.system(size: 28, weight: .medium))
                    }

                VStack(alignment: .leading, spacing: 5) {
                    Text(playback.currentTrack?.title ?? "Belum ada lagu")
                        .font(.headline)
                        .lineLimit(1)
                    Text(playback.currentTrack?.artist ?? "Pilih lagu setelah katalog dihubungkan")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }

            HStack {
                Text(Self.time(playback.position))
                Spacer()
                Text(Self.time(playback.duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)

            Slider(
                value: Binding(
                    get: { playback.position },
                    set: { playback.seek(to: $0) }
                ),
                in: 0...(max(playback.duration, 1))
            )
            .disabled(playback.currentTrack == nil || playback.duration <= 0)

            HStack {
                Spacer()
                Button {
                    playback.togglePlayback()
                } label: {
                    Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2.bold())
                        .frame(width: 58, height: 58)
                        .background(.purple.gradient, in: Circle())
                }
                .disabled(playback.currentTrack == nil)
                .accessibilityLabel(playback.isPlaying ? "Jeda" : "Putar")
                Spacer()
            }

            if let error = playback.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(18)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
    }

    private static func time(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let whole = Int(seconds)
        return "\(whole / 60):\(String(format: "%02d", whole % 60))"
    }
}
