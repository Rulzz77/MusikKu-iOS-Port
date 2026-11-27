import Foundation
import CryptoKit

enum LyricsProvider: String, CaseIterable, Identifiable, Hashable {
    case automatic
    case lrcRed
    case biniLyrics
    case betterLyrics
    case betterLyricsPortato
    case lrcLib

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "Otomatis (disarankan)"
        case .lrcRed: return "lrc.red"
        case .biniLyrics: return "BiniLyrics"
        case .betterLyrics: return "BetterLyrics"
        case .betterLyricsPortato: return "BetterLyrics Portato"
        case .lrcLib: return "LRCLIB"
        }
    }

    var providerName: String {
        switch self {
        case .automatic: return "Otomatis"
        case .lrcRed: return "lrc.red"
        case .biniLyrics: return "BiniLyrics"
        case .betterLyrics: return "BetterLyrics"
        case .betterLyricsPortato: return "BetterLyrics Portato"
        case .lrcLib: return "LRCLIB"
        }
    }
}

struct LyricsSyllable: Hashable {
    let startMilliseconds: Int
    let endMilliseconds: Int
    let startCharacter: Int
    let endCharacter: Int
}

struct LyricsWord: Hashable {
    let startMilliseconds: Int
    let endMilliseconds: Int
    let text: String
    let syllables: [LyricsSyllable]

    func revealedCharacterCount(at position: Int) -> Int {
        let characters = Array(text)
        guard !characters.isEmpty else { return 0 }
        if position <= startMilliseconds { return 0 }
        if position >= endMilliseconds { return characters.count }

        guard !syllables.isEmpty else {
            let span = max(endMilliseconds - startMilliseconds, 1)
            let progress = Double(position - startMilliseconds) / Double(span)
            return min(characters.count, max(0, Int((progress * Double(characters.count)).rounded(.down))))
        }

        for syllable in syllables {
            if position < syllable.startMilliseconds {
                return max(0, min(characters.count, syllable.startCharacter))
            }
            if position < syllable.endMilliseconds {
                let span = max(syllable.endMilliseconds - syllable.startMilliseconds, 1)
                let progress = Double(position - syllable.startMilliseconds) / Double(span)
                let characterSpan = syllable.endCharacter - syllable.startCharacter
                let revealed = syllable.startCharacter + Int((progress * Double(characterSpan)).rounded(.down))
                return max(0, min(characters.count, revealed))
            }
        }
        return characters.count
    }
}

struct LyricsLine: Identifiable, Hashable {
    let id: Int
    let timeMilliseconds: Int?
    let text: String
    var words: [LyricsWord] = []

    var isWordSynchronized: Bool { !words.isEmpty }
}

struct LyricsDocument: Hashable {
    let source: String
    let lines: [LyricsLine]

    var isSynchronized: Bool {
        lines.contains { $0.timeMilliseconds != nil }
    }
}

/// Native lyric-provider chain aligned with the Android repository.
/// BetterLyrics is tried first for timed TTML; LRCLIB is the line-synced fallback.
actor LyricsService {
    static let shared = LyricsService()

    private let session: URLSession
    private var translationCache: [String: LyricsDocument] = [:]
    private var translationCacheOrder: [String] = []

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 7
        configuration.timeoutIntervalForResource = 12
        session = URLSession(configuration: configuration)
    }

    func lyrics(for track: MusicTrack) async -> LyricsDocument? {
        await lyrics(for: track, provider: .automatic)
    }

    func lyrics(for track: MusicTrack, provider: LyricsProvider) async -> LyricsDocument? {
        let title = Self.cleanTitle(track.title)
        let artist = Self.cleanArtist(track.artist)
        guard !title.isEmpty, !artist.isEmpty else { return nil }

        if provider == .automatic,
           let imported = loadImportedTTML(trackID: track.id) {
            return imported
        }

        switch provider {
        case .automatic:
            if let lrcRed = await fetchLrcRed(
                title: title,
                artist: artist,
                durationSeconds: track.durationSeconds
            ) {
                return lrcRed
            }
            if let bini = await fetchBiniLyrics(
                title: title,
                artist: artist,
                album: track.album,
                durationSeconds: track.durationSeconds
            ) {
                return bini
            }
            if let betterLyrics = await fetchBetterLyrics(
                title: title,
                artist: artist,
                album: track.album,
                durationSeconds: track.durationSeconds
            ) {
                return betterLyrics
            }
            if let portato = await fetchBetterLyrics(
                title: title,
                artist: artist,
                album: track.album,
                durationSeconds: track.durationSeconds,
                endpoint: "https://lyrics-api.boidu.dev/qq/getLyrics",
                sourceName: "BetterLyrics Portato"
            ) {
                return portato
            }
            return await fetchLrcLib(
                title: title,
                artist: artist,
                durationSeconds: track.durationSeconds
            )

        case .lrcRed:
            return await fetchLrcRed(title: title, artist: artist, durationSeconds: track.durationSeconds)

        case .biniLyrics:
            return await fetchBiniLyrics(
                title: title,
                artist: artist,
                album: track.album,
                durationSeconds: track.durationSeconds
            )

        case .betterLyrics:
            return await fetchBetterLyrics(
                title: title,
                artist: artist,
                album: track.album,
                durationSeconds: track.durationSeconds
            )

        case .betterLyricsPortato:
            return await fetchBetterLyrics(
                title: title,
                artist: artist,
                album: track.album,
                durationSeconds: track.durationSeconds,
                endpoint: "https://lyrics-api.boidu.dev/qq/getLyrics",
                sourceName: "BetterLyrics Portato"
            )

        case .lrcLib:
            return await fetchLrcLib(
                title: title,
                artist: artist,
                durationSeconds: track.durationSeconds
            )
        }
    }


    /// Imports and stores a local TTML file for this track on the device.
    func importTTML(_ data: Data, trackID: String, sourceName: String) -> LyricsDocument? {
        guard !trackID.isEmpty, trackID.count <= 512,
              !data.isEmpty, data.count <= 5 * 1_024 * 1_024,
              let text = String(data: data, encoding: .utf8),
              text.localizedCaseInsensitiveContains("<tt") else {
            return nil
        }
        let lines = Self.parseTTML(text)
        guard !lines.isEmpty,
              let url = importedTTMLURL(trackID: trackID) else { return nil }

        do {
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
        } catch {
            return nil
        }

        let safeName = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        return LyricsDocument(
            source: safeName.isEmpty ? "TTML lokal" : "TTML • \(safeName)",
            lines: lines
        )
    }

    func hasImportedTTML(trackID: String) -> Bool {
        guard let url = importedTTMLURL(trackID: trackID) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    func deleteImportedTTML(trackID: String) {
        guard let url = importedTTMLURL(trackID: trackID) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func loadImportedTTML(trackID: String) -> LyricsDocument? {
        guard let url = importedTTMLURL(trackID: trackID),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber,
              size.intValue > 0, size.intValue <= 5 * 1_024 * 1_024,
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        let lines = Self.parseTTML(text)
        guard !lines.isEmpty else { return nil }
        return LyricsDocument(source: "TTML lokal", lines: lines)
    }

    private func importedTTMLURL(trackID: String) -> URL? {
        guard !trackID.isEmpty, trackID.count <= 512,
              let root = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
              ).first else {
            return nil
        }
        let digest = SHA256.hash(data: Data(trackID.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return root
            .appendingPathComponent("MusikKu", isDirectory: true)
            .appendingPathComponent("ImportedLyrics", isDirectory: true)
            .appendingPathComponent("\(digest).ttml")
    }

    /// Exports line, word and syllable timestamps to a compact TTML document.
    func exportTTML(_ document: LyricsDocument) -> Data? {
        guard !document.lines.isEmpty else { return nil }

        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <tt xmlns="http://www.w3.org/ns/ttml" xml:lang="und">
          <body><div>
        """

        for (index, line) in document.lines.enumerated() {
            let nextStart = document.lines.dropFirst(index + 1)
                .compactMap(\.timeMilliseconds)
                .first
            let wordEnd = line.words.map(\.endMilliseconds).max()
            let start = line.timeMilliseconds ?? line.words.first?.startMilliseconds
            let inferredEnd = wordEnd ?? start.map { $0 + 3_000 }
            let end: Int?
            if let candidate = nextStart, let start, candidate > start {
                end = candidate
            } else {
                end = inferredEnd
            }

            xml += "\n    <p"
            if let start { xml += " begin=\"\(Self.ttmlTime(start))\"" }
            if let end, let start, end > start { xml += " end=\"\(Self.ttmlTime(end))\"" }
            xml += " xml:space=\"preserve\">"

            if line.words.isEmpty {
                xml += Self.escapeXML(line.text)
            } else {
                for (wordIndex, word) in line.words.enumerated() {
                    if wordIndex > 0 { xml += " " }
                    if word.syllables.count >= 2 {
                        let characters = Array(word.text)
                        for syllable in word.syllables {
                            let lower = max(0, min(characters.count, syllable.startCharacter))
                            let upper = max(lower, min(characters.count, syllable.endCharacter))
                            let text = String(characters[lower..<upper])
                            guard !text.isEmpty else { continue }
                            xml += "<span begin=\"\(Self.ttmlTime(syllable.startMilliseconds))\" end=\"\(Self.ttmlTime(syllable.endMilliseconds))\">\(Self.escapeXML(text))</span>"
                        }
                    } else {
                        xml += "<span begin=\"\(Self.ttmlTime(word.startMilliseconds))\" end=\"\(Self.ttmlTime(word.endMilliseconds))\">\(Self.escapeXML(word.text))</span>"
                    }
                }
            }
            xml += "</p>"
        }

        xml += "\n  </div></body>\n</tt>\n"
        return xml.data(using: .utf8)
    }

    private static func ttmlTime(_ milliseconds: Int) -> String {
        String(format: "%.3fs", Double(max(0, milliseconds)) / 1_000)
    }

    private static func escapeXML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    func translate(
        _ document: LyricsDocument,
        trackID: String,
        targetLanguage: String
    ) async -> LyricsDocument? {
        let target = targetLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty, !document.lines.isEmpty else { return nil }

        let lyricsSignature = document.lines.map(\.text).joined(separator: "\u{0000}")
        let cacheKey = "\(trackID)|\(target)|\(lyricsSignature)"
        if let cached = translationCache[cacheKey] {
            return cached
        }

        var translatedByIndex: [Int: String] = [:]
        let batches = makeTranslationBatches(document.lines)
        guard !batches.isEmpty else { return nil }

        for batch in batches {
            guard let translated = await requestTranslation(batch, targetLanguage: target),
                  translated.count == batch.count else {
                return nil
            }
            for (slot, text) in zip(batch, translated) {
                translatedByIndex[slot.index] = text
            }
        }

        guard !translatedByIndex.isEmpty else { return nil }
        let translatedLines = document.lines.enumerated().map { index, line in
            guard let text = translatedByIndex[index] else { return line }
            return LyricsLine(
                id: line.id,
                timeMilliseconds: line.timeMilliseconds,
                text: text,
                words: []
            )
        }
        let result = LyricsDocument(
            source: "Terjemahan otomatis • \(target.uppercased())",
            lines: translatedLines
        )

        translationCache[cacheKey] = result
        translationCacheOrder.removeAll { $0 == cacheKey }
        translationCacheOrder.append(cacheKey)
        while translationCacheOrder.count > 40 {
            let oldest = translationCacheOrder.removeFirst()
            translationCache.removeValue(forKey: oldest)
        }
        return result
    }

    private struct TranslationSlot {
        let index: Int
        let text: String
    }

    private func makeTranslationBatches(_ lines: [LyricsLine]) -> [[TranslationSlot]] {
        var batches: [[TranslationSlot]] = []
        var current: [TranslationSlot] = []
        var currentLength = 0

        func isSectionHeader(_ text: String) -> Bool {
            text.range(of: #"^\s*\[[^\]]+\]\s*$"#, options: .regularExpression) != nil
        }

        func flush() {
            guard !current.isEmpty else { return }
            batches.append(current)
            current = []
            currentLength = 0
        }

        for (index, line) in lines.enumerated() {
            let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, !isSectionHeader(text) else { continue }
            let addedLength = text.count + (current.isEmpty ? 0 : 16)
            if !current.isEmpty && currentLength + addedLength > 3_200 {
                flush()
            }
            current.append(TranslationSlot(index: index, text: text))
            currentLength += addedLength
        }
        flush()
        return batches
    }

    private func requestTranslation(
        _ slots: [TranslationSlot],
        targetLanguage: String
    ) async -> [String]? {
        guard !slots.isEmpty,
              let url = URL(string: "https://translate.googleapis.com/translate_a/single") else {
            return nil
        }

        let payload = slots.enumerated().map { index, slot in
            index == 0 ? slot.text : "\(Self.translationMarker(index - 1))\n\(slot.text)"
        }.joined(separator: "\n")

        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "client", value: "dict-chrome-ex"),
            URLQueryItem(name: "sl", value: "auto"),
            URLQueryItem(name: "tl", value: targetLanguage),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: payload)
        ]
        guard let formBody = form.percentEncodedQuery?.data(using: .utf8) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 18
        request.httpBody = formBody
        request.setValue("application/x-www-form-urlencoded;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("MusikKu iOS", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let root = try JSONSerialization.jsonObject(with: data) as? [Any],
                  let rawSegments = root.first as? [Any] else {
                return nil
            }

            let translatedBody = rawSegments.compactMap { segment -> String? in
                guard let values = segment as? [Any] else { return nil }
                return values.first as? String
            }.joined()
            return splitTranslation(translatedBody, expectedCount: slots.count)
        } catch {
            return nil
        }
    }

    private func splitTranslation(_ value: String, expectedCount: Int) -> [String]? {
        guard expectedCount > 0 else { return [] }
        var remaining = value[...]
        var result: [String] = []

        if expectedCount > 1 {
            for index in 0..<(expectedCount - 1) {
                let marker = Self.translationMarker(index)
                guard let markerRange = remaining.range(of: marker) else { return nil }
                let text = String(remaining[..<markerRange.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                result.append(text)
                remaining = remaining[markerRange.upperBound...]
            }
        }

        let finalText = String(remaining).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalText.isEmpty else { return nil }
        result.append(finalText)
        return result.count == expectedCount ? result : nil
    }

    private static func translationMarker(_ index: Int) -> String {
        "\u{E000}\(String(format: "%04d", index))\u{E001}"
    }

    private func fetchBiniLyrics(
        title: String,
        artist: String,
        album: String?,
        durationSeconds: Int?
    ) async -> LyricsDocument? {
        guard var components = URLComponents(string: "https://lyrics-api.binimum.org/") else {
            return nil
        }

        var queryItems = [
            URLQueryItem(name: "track", value: title),
            URLQueryItem(name: "artist", value: artist)
        ]
        if let album, !album.isEmpty {
            queryItems.append(URLQueryItem(name: "album", value: album))
        }
        if let durationSeconds, durationSeconds > 0 {
            queryItems.append(URLQueryItem(name: "duration", value: String(durationSeconds)))
        }
        components.queryItems = queryItems

        guard let url = components.url,
              let body = await getData(url),
              let root = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let candidates = root["results"] as? [[String: Any]] else {
            return nil
        }

        let matched = candidates.first { candidate in
            Self.matches(
                title: title,
                artist: artist,
                durationSeconds: durationSeconds,
                candidateTitle: candidate["track_name"] as? String,
                candidateArtist: candidate["artist_name"] as? String,
                candidateDuration: Self.jsonDouble(candidate["duration"])
            ) && candidate["isrc"] as? String != nil &&
                candidate["lyricsUrl"] as? String != nil
        }

        guard let matched else { return nil }
        guard let lyricsURLString = matched["lyricsUrl"] as? String,
              let lyricsURL = URL(string: lyricsURLString),
              lyricsURL.scheme?.lowercased() == "https",
              let host = lyricsURL.host?.lowercased(),
              host == "lrc.red" || host == "lyrics-api.binimum.org",
              Self.isValidISRC(matched["isrc"] as? String),
              let ttml = await getText(
                lyricsURL,
                accept: "application/xml, text/xml, text/plain, */*"
              ) else {
            return nil
        }

        let lines = Self.parseTTML(ttml)
        return lines.isEmpty ? nil : LyricsDocument(source: "BiniLyrics", lines: lines)
    }

    private func fetchLrcRed(
        title: String,
        artist: String,
        durationSeconds: Int?
    ) async -> LyricsDocument? {
        guard var searchComponents = URLComponents(string: "https://lrc.red/search.json") else {
            return nil
        }
        searchComponents.queryItems = [
            URLQueryItem(name: "q", value: "\(title) \(artist)")
        ]

        guard let searchURL = searchComponents.url,
              let body = await getData(searchURL),
              let root = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let hits = root["hits"] as? [[String: Any]] else {
            return nil
        }

        var bestHit: [String: Any]?
        var bestDistance = Double.greatestFiniteMagnitude
        let expectedDuration = Double(durationSeconds ?? 0)

        for hit in hits {
            guard Self.matches(
                title: title,
                artist: artist,
                durationSeconds: durationSeconds,
                candidateTitle: hit["title"] as? String,
                candidateArtist: hit["artist"] as? String,
                candidateDuration: Self.jsonDouble(hit["duration"])
            ), Self.isValidISRC(hit["isrc"] as? String) else {
                continue
            }

            let actualDuration = Self.jsonDouble(hit["duration"])
            let distance: Double
            if expectedDuration > 0, let actualDuration, actualDuration > 0 {
                distance = abs(actualDuration - expectedDuration)
            } else {
                distance = 0
            }

            if distance < bestDistance {
                bestDistance = distance
                bestHit = hit
            }
        }

        guard let matchedHit = bestHit,
              let isrc = matchedHit["isrc"] as? String else {
            return nil
        }
        let urlString = "https://lrc.red/s/\(isrc.uppercased()).ttml"
        guard let lyricsURL = URL(string: urlString),
              let ttml = await getText(
                lyricsURL,
                accept: "application/xml, text/xml, text/plain, */*"
              ) else {
            return nil
        }

        let lines = Self.parseTTML(ttml)
        return lines.isEmpty ? nil : LyricsDocument(source: "lrc.red", lines: lines)
    }

    private func fetchBetterLyrics(
        title: String,
        artist: String,
        album: String?,
        durationSeconds: Int?,
        endpoint: String = "https://lyrics-api.boidu.dev/getLyrics",
        sourceName: String = "BetterLyrics"
    ) async -> LyricsDocument? {
        guard var components = URLComponents(string: endpoint) else {
            return nil
        }

        var queryItems = [
            URLQueryItem(name: "s", value: title),
            URLQueryItem(name: "a", value: artist)
        ]
        if let durationSeconds, durationSeconds > 0 {
            queryItems.append(URLQueryItem(name: "d", value: String(durationSeconds)))
        }
        if let album, !album.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "al", value: album))
        }
        components.queryItems = queryItems

        guard let url = components.url,
              let raw = await getText(url, accept: "application/xml, text/xml, application/json, text/plain, */*"),
              let payload = Self.unwrapProviderPayload(raw) else {
            return nil
        }

        let timedLines = Self.parseTTML(payload)
        if !timedLines.isEmpty {
            return LyricsDocument(source: sourceName, lines: timedLines)
        }

        let lrcLines = Self.parseLRC(payload)
        if !lrcLines.isEmpty {
            return LyricsDocument(source: sourceName, lines: lrcLines)
        }

        let plainLines = Self.parsePlain(payload)
        return plainLines.isEmpty ? nil : LyricsDocument(source: sourceName, lines: plainLines)
    }

    private func fetchLrcLib(
        title: String,
        artist: String,
        durationSeconds: Int?
    ) async -> LyricsDocument? {
        if let durationSeconds, durationSeconds > 0,
           let exactURL = Self.lrcLibURL(
                endpoint: "get",
                title: title,
                artist: artist,
                durationSeconds: durationSeconds
           ),
           let exactBody = await getData(exactURL),
           let exact = try? JSONDecoder().decode(LrcLibTrack.self, from: exactBody) {
            if Self.matches(
                title: title,
                artist: artist,
                durationSeconds: durationSeconds,
                candidate: exact
            ) {
                if let synced = exact.syncedLyrics {
                    let lines = Self.parseLRC(synced)
                    if !lines.isEmpty {
                        return LyricsDocument(source: "LRCLIB", lines: lines)
                    }
                }
                if let plain = exact.plainLyrics {
                    let lines = Self.parsePlain(plain)
                    if !lines.isEmpty {
                        return LyricsDocument(source: "LRCLIB", lines: lines)
                    }
                }
            }
        }

        guard let searchURL = Self.lrcLibURL(endpoint: "search", title: title, artist: artist, durationSeconds: nil),
              let searchBody = await getData(searchURL),
              let hits = try? JSONDecoder().decode([LrcLibTrack].self, from: searchBody) else {
            return nil
        }

        let matched = hits
            .filter {
                Self.matches(
                    title: title,
                    artist: artist,
                    durationSeconds: durationSeconds,
                    candidate: $0
                ) && (($0.syncedLyrics?.isEmpty == false) || ($0.plainLyrics?.isEmpty == false))
            }
            .min {
                abs(($0.duration ?? 0) - Double(durationSeconds ?? 0))
                    < abs(($1.duration ?? 0) - Double(durationSeconds ?? 0))
            }

        guard let matched else { return nil }
        if let synced = matched.syncedLyrics {
            let lines = Self.parseLRC(synced)
            if !lines.isEmpty {
                return LyricsDocument(source: "LRCLIB", lines: lines)
            }
        }
        if let plain = matched.plainLyrics {
            let lines = Self.parsePlain(plain)
            if !lines.isEmpty {
                return LyricsDocument(source: "LRCLIB", lines: lines)
            }
        }
        return nil
    }

    private func getData(_ url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 7
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("MusikKu iOS (https://github.com/Rulzz77/MusikKu-iOS-Port)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            return data
        } catch {
            return nil
        }
    }

    private func getText(_ url: URL, accept: String) async -> String? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 7
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue("MusikKu iOS (https://github.com/Rulzz77/MusikKu-iOS-Port)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private static func lrcLibURL(
        endpoint: String,
        title: String,
        artist: String,
        durationSeconds: Int?
    ) -> URL? {
        guard var components = URLComponents(string: "https://lrclib.net/api/\(endpoint)") else {
            return nil
        }
        var items = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist)
        ]
        if let durationSeconds, durationSeconds > 0 {
            items.append(URLQueryItem(name: "duration", value: String(durationSeconds)))
        }
        components.queryItems = items
        return components.url
    }

    private static func isValidISRC(_ raw: String?) -> Bool {
        guard let raw else { return false }
        return raw.uppercased().range(
            of: #"^[A-Z]{2}[A-Z0-9]{3}[0-9]{7}$"#,
            options: .regularExpression
        ) != nil
    }

    private static func matches(
        title: String,
        artist: String,
        durationSeconds: Int?,
        candidate: LrcLibTrack
    ) -> Bool {
        matches(
            title: title,
            artist: artist,
            durationSeconds: durationSeconds,
            candidateTitle: candidate.trackName,
            candidateArtist: candidate.artistName,
            candidateDuration: candidate.duration
        )
    }

    private static func matches(
        title: String,
        artist: String,
        durationSeconds: Int?,
        candidateTitle: String?,
        candidateArtist: String?,
        candidateDuration: Double?
    ) -> Bool {
        let wantedTitle = identity(cleanTitle(title))
        let foundTitle = identity(cleanTitle(candidateTitle ?? ""))
        guard !wantedTitle.isEmpty, wantedTitle == foundTitle else { return false }

        let wantedArtists = artistNames(cleanArtist(artist))
        let foundArtists = artistNames(cleanArtist(candidateArtist ?? ""))
        guard !wantedArtists.isEmpty, !foundArtists.isEmpty,
              !wantedArtists.isDisjoint(with: foundArtists) else {
            return false
        }

        if let durationSeconds, durationSeconds > 0,
           let candidateDuration, candidateDuration > 0 {
            guard abs(candidateDuration - Double(durationSeconds)) <= 5 else { return false }
        }
        return true
    }

    private static func jsonDouble(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }

    private static func cleanTitle(_ value: String) -> String {
        var title = value
        let patterns = [
            #"\s*[\(\[]\s*(feat|ft|featuring|with)\b[^\)\]]*[\)\]]"#,
            #"\s+(feat|ft|featuring)\.?\s+.*$"#,
            #"\s*[\(\[]\s*(official\s*)?(music\s*)?(video|audio|visuali[sz]er|lyrics?\s*video|lyrics?|m/?v|hd|hq|4k|full\s*song)\s*[\)\]]"#,
            #"\s*[\(\[]\s*official\s*[\)\]]"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(title.startIndex..., in: title)
                title = regex.stringByReplacingMatches(in: title, range: range, withTemplate: " ")
            }
        }
        return title
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ",-–— "))
    }

    private static func cleanArtist(_ value: String) -> String {
        value.replacingOccurrences(of: " - Topic", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func identity(_ value: String) -> String {
        let folded = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let pieces = folded.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? String(scalar) : " "
        }
        return pieces.joined()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private static func artistNames(_ value: String) -> Set<String> {
        let separators = try? NSRegularExpression(
            pattern: #"\s*(?:,|&|;|/|\band\b|\bx\b|\bwith\b|\bfeat\.?\b|\bft\.?\b)\s*"#,
            options: [.caseInsensitive]
        )
        let range = NSRange(value.startIndex..., in: value)
        let separated = separators?.stringByReplacingMatches(in: value, range: range, withTemplate: "|") ?? value
        return Set(separated.split(separator: "|").map { identity(String($0)) }.filter { !$0.isEmpty })
    }

    private static func parseLRC(_ value: String) -> [LyricsLine] {
        guard let stampRegex = try? NSRegularExpression(
            pattern: #"\[(\d{1,3}):(\d{2})(?:[.:](\d{2,3}))?\]"#
        ) else { return [] }

        var lines: [LyricsLine] = []
        for rawLine in value.components(separatedBy: .newlines) {
            let range = NSRange(rawLine.startIndex..., in: rawLine)
            let matches = stampRegex.matches(in: rawLine, range: range)
            guard let last = matches.last,
                  let lastRange = Range(last.range, in: rawLine) else { continue }

            let body = String(rawLine[lastRange.upperBound...])
                .replacingOccurrences(of: #"<\d{1,3}:\d{2}[.:]\d{2,3}>"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { continue }

            for match in matches {
                guard match.numberOfRanges >= 4,
                      let minutesRange = Range(match.range(at: 1), in: rawLine),
                      let secondsRange = Range(match.range(at: 2), in: rawLine) else { continue }

                let minutes = Int(rawLine[minutesRange]) ?? 0
                let seconds = Int(rawLine[secondsRange]) ?? 0
                let fractionText: String
                if let fractionRange = Range(match.range(at: 3), in: rawLine) {
                    fractionText = String(rawLine[fractionRange])
                } else {
                    fractionText = ""
                }
                let fraction = Int(fractionText) ?? 0
                let fractionMs = fractionText.count == 2 ? fraction * 10 : fraction
                let stamp = minutes * 60_000 + seconds * 1_000 + fractionMs
                lines.append(LyricsLine(
                    id: lines.count,
                    timeMilliseconds: stamp,
                    text: body
                ))
            }
        }
        return lines.sorted {
            ($0.timeMilliseconds ?? 0) < ($1.timeMilliseconds ?? 0)
        }.enumerated().map { index, line in
            LyricsLine(id: index, timeMilliseconds: line.timeMilliseconds, text: line.text, words: line.words)
        }
    }

    private static func parseTTML(_ value: String) -> [LyricsLine] {
        guard value.localizedCaseInsensitiveContains("<tt") else { return [] }
        let delegate = TTMLLineParser()
        let parser = XMLParser(data: Data(value.utf8))
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        guard parser.parse() else { return [] }
        return delegate.lines.enumerated().map { index, line in
            LyricsLine(id: index, timeMilliseconds: line.timeMilliseconds, text: line.text)
        }
    }

    private static func parsePlain(_ value: String) -> [LyricsLine] {
        let rows = value.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { !$0.matches(#"^\[[A-Za-z]+:.*\]$"#) }
        return rows.enumerated().map { index, text in
            LyricsLine(id: index, timeMilliseconds: nil, text: text)
        }
    }

    private static func unwrapProviderPayload(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return trimmed
        }
        return findLyricsString(in: object)
    }

    private static func findLyricsString(in value: Any) -> String? {
        if let string = value as? String {
            return string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : string
        }
        if let object = value as? [String: Any] {
            for key in ["ttml", "ttmlContent", "lyrics", "lrc", "content", "text", "plainLyrics", "syncedLyrics"] {
                if let child = object[key], let found = findLyricsString(in: child) {
                    return found
                }
            }
            if let metadata = object["metadata"], let found = findLyricsString(in: metadata) {
                return found
            }
        }
        if let array = value as? [Any] {
            return array.compactMap(findLyricsString).joined(separator: "\n").nonEmpty
        }
        return nil
    }

    private struct LrcLibTrack: Decodable {
        let trackName: String?
        let artistName: String?
        let duration: Double?
        let syncedLyrics: String?
        let plainLyrics: String?
    }
}

private final class TTMLNode {
    let name: String
    let attributes: [String: String]
    var children: [TTMLChild] = []

    init(name: String, attributes: [String: String]) {
        self.name = name
        self.attributes = attributes
    }

    var textContent: String {
        children.map { child in
            switch child {
            case .text(let text): return text
            case .element(let node): return node.textContent
            }
        }
        .joined()
    }
}

private enum TTMLChild {
    case text(String)
    case element(TTMLNode)
}

private enum TTMLPiece {
    case text(String)
    case timed(String, start: Int, end: Int)
}

private final class TTMLLineParser: NSObject, XMLParserDelegate {
    private static let maximumDepth = 64
    private static let maximumNodes = 20_000
    private static let maximumTextBytes = 1_024 * 1_024

    private var roots: [TTMLNode] = []
    private var stack: [TTMLNode] = []
    private var nodeCount = 0
    private var textByteCount = 0

    var lines: [LyricsLine] {
        Self.collectParagraphs(from: roots)
            .compactMap(Self.makeLine)
            .sorted { ($0.timeMilliseconds ?? 0) < ($1.timeMilliseconds ?? 0) }
            .enumerated()
            .map { index, line in
                LyricsLine(
                    id: index,
                    timeMilliseconds: line.timeMilliseconds,
                    text: line.text,
                    words: line.words
                )
            }
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard stack.count < Self.maximumDepth, nodeCount < Self.maximumNodes else {
            parser.abortParsing()
            return
        }
        nodeCount += 1

        let node = TTMLNode(name: elementName, attributes: attributeDict)
        if let parent = stack.last {
            parent.children.append(.element(node))
        } else {
            roots.append(node)
        }
        stack.append(node)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let size = string.utf8.count
        guard textByteCount <= Self.maximumTextBytes - size else {
            parser.abortParsing()
            return
        }
        textByteCount += size
        stack.last?.children.append(.text(string))
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard let value = String(data: CDATABlock, encoding: .utf8) else { return }
        guard textByteCount <= Self.maximumTextBytes - CDATABlock.count else {
            parser.abortParsing()
            return
        }
        textByteCount += CDATABlock.count
        stack.last?.children.append(.text(value))
    }

    // TTML does not require DTDs or custom entities; reject them to avoid entity-expansion payloads.
    func parser(
        _ parser: XMLParser,
        foundInternalEntityDeclarationWithName name: String,
        value: String?
    ) {
        parser.abortParsing()
    }

    func parser(
        _ parser: XMLParser,
        foundExternalEntityDeclarationWithName name: String,
        publicID: String?,
        systemID: String?
    ) {
        parser.abortParsing()
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard !stack.isEmpty else { return }
        stack.removeLast()
    }

    private static func collectParagraphs(from nodes: [TTMLNode]) -> [TTMLNode] {
        var result: [TTMLNode] = []
        func walk(_ node: TTMLNode) {
            if node.name == "p" {
                result.append(node)
                return
            }
            for child in node.children {
                if case .element(let childNode) = child {
                    walk(childNode)
                }
            }
        }
        nodes.forEach(walk)
        return result
    }

    private static func makeLine(_ paragraph: TTMLNode) -> LyricsLine? {
        let pieces = collectPieces(from: paragraph)
        let words = mergeIntoWords(pieces)
        let begin = timeMilliseconds(paragraph.attributes["begin"])
            ?? words.first?.startMilliseconds
        let plainText = paragraph.textContent
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let text = words.isEmpty ? plainText : words.map(\.text).joined(separator: " ")
        guard !text.isEmpty else { return nil }

        return LyricsLine(
            id: 0,
            timeMilliseconds: begin,
            text: text,
            words: words
        )
    }

    private static func collectPieces(from root: TTMLNode) -> [TTMLPiece] {
        var output: [TTMLPiece] = []

        func hasTimedDescendant(_ node: TTMLNode) -> Bool {
            for child in node.children {
                guard case .element(let nested) = child else { continue }
                if nested.attributes["begin"] != nil || nested.attributes["end"] != nil {
                    return true
                }
                if hasTimedDescendant(nested) { return true }
            }
            return false
        }

        func collect(_ node: TTMLNode) {
            for child in node.children {
                switch child {
                case .text(let text):
                    if !text.isEmpty { output.append(.text(text)) }
                case .element(let element):
                    let role = element.attributes["ttm:role"] ?? element.attributes["role"] ?? ""
                    if role == "x-translation" || role == "x-roman" { continue }

                    let start = timeMilliseconds(element.attributes["begin"])
                    let end = timeMilliseconds(element.attributes["end"])
                    if let start, let end, end > start, !hasTimedDescendant(element) {
                        let text = element.textContent
                        if !text.isEmpty {
                            output.append(.timed(text, start: start, end: end))
                        }
                    } else {
                        collect(element)
                    }
                }
            }
        }

        collect(root)
        return output
    }

    private static func mergeIntoWords(_ pieces: [TTMLPiece]) -> [LyricsWord] {
        var result: [LyricsWord] = []
        var currentText = ""
        var syllables: [LyricsSyllable] = []
        var wordStart = 0
        var wordEnd = 0
        var hasTimedText = false

        func normalizedSyllables(_ parts: [LyricsSyllable], length: Int) -> [LyricsSyllable] {
            let usable = parts
                .filter { $0.endCharacter > $0.startCharacter && $0.startCharacter < length }
                .sorted { $0.startCharacter < $1.startCharacter }
            guard usable.count >= 2 else { return [] }
            return usable.enumerated().map { index, part in
                LyricsSyllable(
                    startMilliseconds: part.startMilliseconds,
                    endMilliseconds: max(part.startMilliseconds, part.endMilliseconds),
                    startCharacter: index == 0 ? 0 : part.startCharacter,
                    endCharacter: usable.dropFirst(index + 1).first?.startCharacter ?? length
                )
            }
        }

        func flush() {
            let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if hasTimedText && !text.isEmpty {
                result.append(
                    LyricsWord(
                        startMilliseconds: wordStart,
                        endMilliseconds: max(wordStart, wordEnd),
                        text: text,
                        syllables: normalizedSyllables(syllables, length: text.count)
                    )
                )
            }
            currentText = ""
            syllables.removeAll(keepingCapacity: true)
            hasTimedText = false
        }

        for piece in pieces {
            switch piece {
            case .text(let text):
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    flush()
                } else if hasTimedText {
                    currentText += text
                }

            case .timed(let rawText, let start, let end):
                guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

                if rawText.first?.isWhitespace == true {
                    flush()
                }
                if currentText.isEmpty {
                    wordStart = start
                }

                let cleaned = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
                let startCharacter = currentText.count
                currentText += cleaned
                let endCharacter = currentText.count
                syllables.append(
                    LyricsSyllable(
                        startMilliseconds: start,
                        endMilliseconds: end,
                        startCharacter: startCharacter,
                        endCharacter: endCharacter
                    )
                )
                wordEnd = end
                hasTimedText = true

                if rawText.last?.isWhitespace == true {
                    flush()
                }
            }
        }

        flush()
        return result
    }

    private static func timeMilliseconds(_ raw: String?) -> Int? {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        if value.hasSuffix("ms") {
            value.removeLast(2)
            guard let milliseconds = Double(value) else { return nil }
            return Int(milliseconds.rounded())
        }
        if value.hasSuffix("s") {
            value.removeLast()
            guard let seconds = Double(value) else { return nil }
            return Int((seconds * 1_000).rounded())
        }

        let parts = value.split(separator: ":")
        if parts.count == 3 {
            let hours = Double(parts[0]) ?? 0
            let minutes = Double(parts[1]) ?? 0
            let seconds = Double(parts[2]) ?? 0
            return Int(((hours * 3_600 + minutes * 60 + seconds) * 1_000).rounded())
        }
        if parts.count == 2 {
            let minutes = Double(parts[0]) ?? 0
            let seconds = Double(parts[1]) ?? 0
            return Int(((minutes * 60 + seconds) * 1_000).rounded())
        }
        if let seconds = Double(value) {
            return Int((seconds * 1_000).rounded())
        }
        return nil
    }
}

private extension String {
    func matches(_ pattern: String) -> Bool {
        range(of: pattern, options: .regularExpression) != nil
    }

    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
