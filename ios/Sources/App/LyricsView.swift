import SwiftUI

struct LyricsSheet: View {
    @EnvironmentObject private var playback: PlaybackManager
    @Environment(\.dismiss) private var dismiss

    let track: MusicTrack

    @State private var document: LyricsDocument?
    @State private var isLoading = true

    private var activeLineID: Int? {
        guard let document, document.isSynchronized else { return nil }
        let position = Int((playback.position * 1_000).rounded())
        return document.lines.last(where: { ($0.timeMilliseconds ?? Int.max) <= position })?.id
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView().tint(MusikKuStyle.accent)
                        Text("Mencari lirik…")
                            .font(.subheadline)
                            .foregroundStyle(MusikKuStyle.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let document {
                    lyricsContent(document)
                } else {
                    emptyState
                }
            }
            .background(MusikKuStyle.background.ignoresSafeArea())
            .navigationTitle("Lirik")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.caption2)
                            .foregroundStyle(MusikKuStyle.secondary)
                            .lineLimit(1)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Tutup") { dismiss() }
                }
            }
        }
        .task(id: track.id) {
            await loadLyrics()
        }
    }

    private func lyricsContent(_ document: LyricsDocument) -> some View {
        VStack(spacing: 10) {
            HStack {
                Label(document.source, systemImage: document.isSynchronized ? "waveform" : "text.alignleft")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MusikKuStyle.secondary)

                Spacer()

                if document.isSynchronized {
                    Text("SINKRON")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(MusikKuStyle.accent)
                } else {
                    Text("TEKS")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(MusikKuStyle.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 23) {
                        ForEach(document.lines) { line in
                            Text(line.text)
                                .font(.system(size: 24, weight: line.id == activeLineID ? .bold : .semibold, design: .rounded))
                                .foregroundStyle(line.id == activeLineID ? .white : Color.white.opacity(document.isSynchronized ? 0.42 : 0.82))
                                .scaleEffect(line.id == activeLineID ? 1.015 : 1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .id(line.id)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 26)
                    .padding(.bottom, 48)
                }
                .onChange(of: activeLineID) { nextID in
                    guard let nextID else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(nextID, anchor: .center)
                    }
                }
                .onAppear {
                    if let activeLineID {
                        proxy.scrollTo(activeLineID, anchor: .center)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 13) {
            Image(systemName: "quote.bubble")
                .font(.system(size: 42))
                .foregroundStyle(MusikKuStyle.accent)

            Text("Lirik belum tersedia")
                .font(.title3.bold())

            Text("Belum ditemukan lirik yang cocok untuk lagu ini. Coba lagi saat koneksi tersedia atau periksa metadata judul dan artis.")
                .font(.subheadline)
                .foregroundStyle(MusikKuStyle.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @MainActor
    private func loadLyrics() async {
        isLoading = true
        defer { isLoading = false }
        document = await LyricsService.shared.lyrics(for: track)
    }
}
