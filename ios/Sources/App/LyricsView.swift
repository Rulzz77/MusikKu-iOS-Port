import SwiftUI

private struct LyricsTranslationTarget: Identifiable, Hashable {
    let code: String
    let title: String

    var id: String { code }

    static let all: [LyricsTranslationTarget] = [
        .init(code: "id", title: "Indonesia"),
        .init(code: "en", title: "English"),
        .init(code: "ms", title: "Melayu"),
        .init(code: "ja", title: "日本語"),
        .init(code: "ko", title: "한국어"),
        .init(code: "zh-CN", title: "中文（简体）"),
        .init(code: "zh-TW", title: "中文（繁體）"),
        .init(code: "es", title: "Español"),
        .init(code: "fr", title: "Français"),
        .init(code: "de", title: "Deutsch")
    ]
}

struct LyricsSheet: View {
    @EnvironmentObject private var playback: PlaybackManager
    @Environment(\.dismiss) private var dismiss

    let track: MusicTrack

    @State private var document: LyricsDocument?
    @State private var translatedDocument: LyricsDocument?
    @State private var showingTranslation = false
    @State private var isTranslating = false
    @State private var translationError: String?
    @State private var translationTarget = UserDefaults.standard.string(forKey: "musikku.lyrics.translation-target.v1") ?? "id"
    @State private var isLoading = true

    private var displayedDocument: LyricsDocument? {
        showingTranslation ? (translatedDocument ?? document) : document
    }

    private var activeLineID: Int? {
        guard let displayedDocument, displayedDocument.isSynchronized else { return nil }
        let position = Int((playback.position * 1_000).rounded())
        return displayedDocument.lines.last(where: { ($0.timeMilliseconds ?? Int.max) <= position })?.id
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
                    lyricsContent(displayedDocument ?? document)
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
                    Menu {
                        Picker("Bahasa tujuan", selection: $translationTarget) {
                            ForEach(LyricsTranslationTarget.all) { target in
                                Text(target.title).tag(target.code)
                            }
                        }
                        Button {
                            Task { await translateLyrics() }
                        } label: {
                            Label("Terjemahkan lirik", systemImage: "translate")
                        }
                        .disabled(document == nil || isTranslating)
                        if showingTranslation {
                            Button {
                                showingTranslation = false
                            } label: {
                                Label("Tampilkan lirik asli", systemImage: "text.alignleft")
                            }
                        }
                    } label: {
                        Image(systemName: "translate")
                    }
                    .accessibilityLabel("Terjemahkan lirik")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Tutup") { dismiss() }
                }
            }
        }
        .task(id: track.id) {
            await loadLyrics()
        }
        .onChange(of: translationTarget) { newValue in
            UserDefaults.standard.set(newValue, forKey: "musikku.lyrics.translation-target.v1")
            showingTranslation = false
            translationError = nil
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

            if showingTranslation {
                Text("Teks lirik dikirim ke layanan terjemahan pihak ketiga. Periksa kembali istilah dan nama khusus.")
                    .font(.caption2)
                    .foregroundStyle(MusikKuStyle.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
            }

            if isTranslating {
                HStack(spacing: 8) {
                    ProgressView().tint(MusikKuStyle.accent)
                    Text("Menerjemahkan lirik…")
                        .font(.caption)
                        .foregroundStyle(MusikKuStyle.secondary)
                }
            }

            if let translationError {
                Text(translationError)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 20)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 23) {
                        ForEach(document.lines) { line in
                            Group {
                                if line.id == activeLineID && line.isWordSynchronized {
                                    karaokeText(line, at: Int((playback.position * 1_000).rounded()))
                                } else {
                                    Text(line.text)
                                        .foregroundColor(line.id == activeLineID ? .white : Color.white.opacity(document.isSynchronized ? 0.42 : 0.82))
                                }
                            }
                            .font(.system(size: 24, weight: line.id == activeLineID ? .bold : .semibold, design: .rounded))
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

    private func karaokeText(_ line: LyricsLine, at position: Int) -> Text {
        var result = Text("")

        for (index, word) in line.words.enumerated() {
            let characters = Array(word.text)
            let revealed = min(characters.count, max(0, word.revealedCharacterCount(at: position)))

            if revealed > 0 {
                result = result + Text(String(characters.prefix(revealed)))
                    .foregroundColor(.white)
            }
            if revealed < characters.count {
                result = result + Text(String(characters.dropFirst(revealed)))
                    .foregroundColor(Color.white.opacity(0.38))
            }
            if index < line.words.count - 1 {
                result = result + Text(" ")
            }
        }

        return result
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
    private func translateLyrics() async {
        guard let document, !isTranslating else { return }
        isTranslating = true
        translationError = nil
        defer { isTranslating = false }

        guard let translated = await LyricsService.shared.translate(
            document,
            trackID: track.id,
            targetLanguage: translationTarget
        ) else {
            translationError = "Terjemahan belum tersedia. Periksa koneksi atau coba bahasa lain."
            return
        }
        translatedDocument = translated
        showingTranslation = true
    }

    @MainActor
    private func loadLyrics() async {
        isLoading = true
        translatedDocument = nil
        showingTranslation = false
        translationError = nil
        defer { isLoading = false }
        document = await LyricsService.shared.lyrics(for: track)
    }
}
