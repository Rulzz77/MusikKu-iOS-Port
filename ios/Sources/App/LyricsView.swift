import SwiftUI
import UniformTypeIdentifiers

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

extension UTType {
    static let musikKuTTML = UTType(importedAs: "org.musikku.ttml", conformingTo: .xml)
}

struct LyricsTTMLFile: FileDocument {
    static var readableContentTypes: [UTType] { [.musikKuTTML, .xml, .plainText] }
    static var writableContentTypes: [UTType] { [.musikKuTTML, .xml] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
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
    @State private var fileError: String?
    @State private var isImportingTTML = false
    @State private var isExportingTTML = false
    @State private var exportFile: LyricsTTMLFile?
    @State private var translationTarget = UserDefaults.standard.string(forKey: "musikku.lyrics.translation-target.v1") ?? "id"
    @State private var selectedProvider = LyricsProvider(rawValue: UserDefaults.standard.string(forKey: "musikku.lyrics.provider.v1") ?? "") ?? .automatic
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

                        Picker("Sumber lirik", selection: $selectedProvider) {
                            ForEach(LyricsProvider.allCases) { provider in
                                Text(provider.title).tag(provider)
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
                        Divider()
                        Button {
                            isImportingTTML = true
                        } label: {
                            Label("Impor file TTML", systemImage: "square.and.arrow.down")
                        }
                        if hasImportedTTML {
                            Button(role: .destructive) {
                                Task { await removeImportedTTML() }
                            } label: {
                                Label("Hapus TTML lokal", systemImage: "trash")
                            }
                        }
                        Button {
                            Task { await prepareTTMLExport() }
                        } label: {
                            Label("Ekspor ke TTML", systemImage: "square.and.arrow.up")
                        }
                        .disabled(document == nil || isLoading)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Menu lirik")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Tutup") { dismiss() }
                }
            }
        }
        .task(id: "\(track.id)|\(selectedProvider.rawValue)") {
            await loadLyrics()
        }
        .onChange(of: translationTarget) { newValue in
            UserDefaults.standard.set(newValue, forKey: "musikku.lyrics.translation-target.v1")
            showingTranslation = false
            translationError = nil
        }

        .onChange(of: selectedProvider) { newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: "musikku.lyrics.provider.v1")
        }
        .fileImporter(
            isPresented: $isImportingTTML,
            allowedContentTypes: [.musikKuTTML, .xml, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let didStartAccessing = url.startAccessingSecurityScopedResource()
                defer {
                    if didStartAccessing { url.stopAccessingSecurityScopedResource() }
                }
                do {
                    let handle = try FileHandle(forReadingFrom: url)
                    defer { try? handle.close() }
                    let data = try handle.read(upToCount: 5 * 1_024 * 1_024 + 1) ?? Data()
                    guard data.count <= 5 * 1_024 * 1_024 else {
                        fileError = "File TTML terlalu besar. Batas impor adalah 5 MB."
                        return
                    }
                    Task {
                        guard let imported = await LyricsService.shared.importTTML(
                            data,
                            trackID: track.id,
                            sourceName: url.deletingPathExtension().lastPathComponent
                        ) else {
                            fileError = "File tidak valid atau tidak berisi baris TTML yang dapat dibaca."
                            return
                        }
                        document = imported
                        translatedDocument = nil
                        showingTranslation = false
                        translationError = nil
                        hasImportedTTML = true
                        selectedProvider = .automatic
                        fileError = nil
                    }
                } catch {
                    fileError = "File TTML tidak dapat dibaca: \(error.localizedDescription)"
                }
            case .failure(let error):
                fileError = "Impor TTML dibatalkan atau gagal: \(error.localizedDescription)"
            }
        }
        .fileExporter(
            isPresented: $isExportingTTML,
            document: exportFile,
            contentType: .musikKuTTML,
            defaultFilename: "\(Self.safeFileName(track.title))-lyrics"
        ) { result in
            if case .failure(let error) = result {
                fileError = "Ekspor TTML gagal: \(error.localizedDescription)"
            } else {
                fileError = nil
            }
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

            if let fileError {
                Text(fileError)
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
    private func prepareTTMLExport() async {
        guard let document,
              let data = await LyricsService.shared.exportTTML(document) else {
            fileError = "Tidak ada lirik yang dapat diekspor."
            return
        }
        exportFile = LyricsTTMLFile(data: data)
        fileError = nil
        isExportingTTML = true
    }

    private static func safeFileName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let cleaned = String(value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "MusikKu" : String(cleaned.prefix(70))
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
        hasImportedTTML = await LyricsService.shared.hasImportedTTML(trackID: track.id)
        document = await LyricsService.shared.lyrics(for: track, provider: selectedProvider)
    }

    @MainActor
    private func removeImportedTTML() async {
        LyricsService.shared.deleteImportedTTML(trackID: track.id)
        hasImportedTTML = false
        selectedProvider = .automatic
        translatedDocument = nil
        showingTranslation = false
        await loadLyrics()
    }
}
