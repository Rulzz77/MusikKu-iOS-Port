import Foundation

struct SpotifySourceTrack: Hashable, Identifiable {
    let position: Int
    let title: String
    let artistText: String
    let artistNames: [String]
    let durationMilliseconds: Int?
    let album: String?
    let spotifyID: String?
    let metadataAvailable: Bool

    var id: String { "\(position)|\(spotifyID ?? title)" }
    var leadArtist: String { artistNames.first ?? artistText }
}

struct SpotifyPlaylistImportEntry: Identifiable {
    let source: SpotifySourceTrack
    let matchedTrack: MusicTrack?
    let lookupFailure: String?

    var id: String { source.id }
}

struct SpotifyPlaylistImportResult {
    let title: String
    let description: String
    let artworkURL: URL?
    let entries: [SpotifyPlaylistImportEntry]

    var matchedTracks: [MusicTrack] {
        var seen = Set<String>()
        return entries.compactMap(\.matchedTrack).filter { track in
            let id = track.id.trimmingCharacters(in: .whitespacesAndNewlines)
            return !id.isEmpty && seen.insert(id).inserted
        }
    }

    var unmatchedEntries: [SpotifyPlaylistImportEntry] {
        entries.filter { $0.matchedTrack == nil && $0.lookupFailure == nil }
    }

    var failedEntries: [SpotifyPlaylistImportEntry] {
        entries.filter { $0.lookupFailure != nil }
    }
}

enum SpotifyPlaylistImportError: LocalizedError {
    case invalidLink
    case requestFailed
    case unavailablePlaylist
    case noTracks
    case incompletePlaylist

    var errorDescription: String? {
        switch self {
        case .invalidLink:
            return "Masukkan tautan playlist Spotify yang valid."
        case .requestFailed:
            return "Playlist Spotify tidak dapat dimuat. Periksa jaringan lalu coba lagi."
        case .unavailablePlaylist:
            return "Playlist tidak tersedia untuk publik atau format Spotify berubah."
        case .noTracks:
            return "Tidak ada lagu yang dapat dibaca dari playlist ini."
        case .incompletePlaylist:
            return "Spotify hanya memberikan sebagian isi playlist. Impor dibatalkan agar playlist tidak tersimpan dalam keadaan terpotong."
        }
    }
}

/// Anonymous importer for public Spotify playlists. It never requests Spotify
/// sign-in or sends Google/Spotify account cookies. Only confidently matched
/// YouTube Music song rows are saved to the device's local library.
actor SpotifyPlaylistImportService {
    static let shared = SpotifyPlaylistImportService()

    typealias ProgressHandler = @MainActor @Sendable (Int, Int) -> Void

    private let session: URLSession
    private let embedTrackLimit = 100
    private let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    init(session: URLSession? = nil) {
        self.session = session ?? Self.makeAnonymousSession()
    }

    /// Uses an isolated in-memory session: no shared cookie storage or shared response cache.
    private static func makeAnonymousSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 60
        configuration.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: configuration)
    }

    func importPlaylist(
        from rawInput: String,
        progress: @escaping ProgressHandler
    ) async throws -> SpotifyPlaylistImportResult {
        guard let playlistID = Self.extractPlaylistID(from: rawInput) else {
            throw SpotifyPlaylistImportError.invalidLink
        }

        let playlist = try await fetchPublicPlaylist(playlistID: playlistID)
        let total = playlist.tracks.count
        let storageCount = (playlist.tracks.map(\.position).max() ?? -1) + 1
        var entries = Array<SpotifyPlaylistImportEntry?>(repeating: nil, count: storageCount)
        var completed = 0

        // Keep concurrency low to avoid flooding the catalogue endpoint.
        for batchStart in stride(from: 0, to: total, by: 3) {
            try Task.checkCancellation()
            let batchEnd = min(batchStart + 3, total)
            let batch = Array(playlist.tracks[batchStart..<batchEnd])
            let batchResults = await withTaskGroup(of: (Int, SpotifyPlaylistImportEntry).self) { group in
                for source in batch {
                    group.addTask {
                        let entry = await Self.resolve(source)
                        return (source.position, entry)
                    }
                }

                var collected: [(Int, SpotifyPlaylistImportEntry)] = []
                for await value in group {
                    collected.append(value)
                }
                return collected
            }

            for (position, entry) in batchResults where entries.indices.contains(position) {
                entries[position] = entry
                completed += 1
            }
            await progress(completed, total)
        }

        return SpotifyPlaylistImportResult(
            title: playlist.title,
            description: playlist.description,
            artworkURL: playlist.artworkURL,
            entries: entries.compactMap { $0 }
        )
    }

    static func extractPlaylistID(from rawInput: String) -> String? {
        let input = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return nil }

        if input.hasPrefix("spotify:playlist:") {
            let identifier = input
                .replacingOccurrences(of: "spotify:playlist:", with: "")
                .components(separatedBy: CharacterSet(charactersIn: "?/"))
                .first ?? ""
            return identifier.range(of: #"^[A-Za-z0-9]{22}$"#, options: .regularExpression) != nil
                ? identifier
                : nil
        }

        guard let url = URLComponents(string: input),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = url.host?.lowercased(),
              host == "spotify.com" || host.hasSuffix(".spotify.com") else {
            return nil
        }

        let parts = url.path.split(separator: "/").map(String.init)
        guard let playlistIndex = parts.firstIndex(of: "playlist"),
              parts.indices.contains(playlistIndex + 1) else { return nil }
        let identifier = parts[playlistIndex + 1]
        return identifier.range(of: #"^[A-Za-z0-9]{22}$"#, options: .regularExpression) != nil
            ? identifier
            : nil
    }

    private func fetchPublicPlaylist(playlistID: String) async throws -> (
        title: String,
        description: String,
        artworkURL: URL?,
        tracks: [SpotifySourceTrack]
    ) {
        guard let url = URL(string: "https://open.spotify.com/embed/playlist/\(playlistID)") else {
            throw SpotifyPlaylistImportError.invalidLink
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 25
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SpotifyPlaylistImportError.requestFailed
        }

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              data.count <= 10 * 1024 * 1024,
              let html = String(data: data, encoding: .utf8) else {
            throw SpotifyPlaylistImportError.unavailablePlaylist
        }

        let pattern = #"<script\b[^>]*\bid=["']__NEXT_DATA__["'][^>]*>(.*?)</script>"#
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.dotMatchesLineSeparators]
        ),
        let match = regex.firstMatch(
            in: html,
            range: NSRange(html.startIndex..., in: html)
        ),
        let jsonRange = Range(match.range(at: 1), in: html) else {
            throw SpotifyPlaylistImportError.unavailablePlaylist
        }

        let root: [String: Any]
        do {
            guard let decoded = try JSONSerialization.jsonObject(
                with: Data(html[jsonRange].utf8)
            ) as? [String: Any] else {
                throw SpotifyPlaylistImportError.unavailablePlaylist
            }
            root = decoded
        } catch {
            throw SpotifyPlaylistImportError.unavailablePlaylist
        }

        let pageProps = Self.dictionary(Self.nested(root, ["props", "pageProps"])) ?? [:]
        let state = Self.dictionary(pageProps["state"]) ?? [:]
        let stateData = Self.dictionary(Self.nested(state, ["data", "entity"]))
            ?? Self.dictionary(pageProps["entity"])
            ?? [:]

        guard !stateData.isEmpty else {
            throw SpotifyPlaylistImportError.unavailablePlaylist
        }

        let title = Self.text(stateData["name"])
            ?? Self.text(stateData["title"])
            ?? "Spotify Playlist"
        let description = Self.text(stateData["description"]) ?? ""
        let artworkURL = Self.playlistArtworkURL(stateData)

        let rawTracks = stateData["trackList"] as? [Any]
            ?? stateData["tracks"] as? [Any]
            ?? []
        guard !rawTracks.isEmpty else { throw SpotifyPlaylistImportError.noTracks }

        let reportedTotal = Self.integer(stateData["totalCount"])
            ?? Self.integer(stateData["trackCount"])
            ?? Self.integer(Self.nested(stateData, ["tracks", "totalCount"]))

        if reportedTotal.map({ $0 > rawTracks.count }) ?? (rawTracks.count >= embedTrackLimit) {
            throw SpotifyPlaylistImportError.incompletePlaylist
        }

        let parsedTracks = rawTracks.enumerated().compactMap { position, raw -> SpotifySourceTrack? in
            let wrapper = Self.dictionary(raw) ?? [:]
            let item = Self.dictionary(Self.nested(wrapper, ["itemV2", "data"])) ?? wrapper
            let parsedTitle = Self.text(item["title"]) ?? Self.text(item["name"])
            let metadataAvailable = parsedTitle != nil
            let title = parsedTitle ?? "Track tidak tersedia"

            let artistsObject = item["artists"]
            let artistItems = artistsObject as? [Any]
                ?? (Self.dictionary(artistsObject)?["items"] as? [Any])
                ?? []
            let artistNames = artistItems.compactMap { rawArtist -> String? in
                let artist = Self.dictionary(rawArtist) ?? [:]
                let profile = Self.dictionary(artist["profile"]) ?? [:]
                return (Self.text(artist["name"]) ?? Self.text(profile["name"]))?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty }

            let artistText = artistNames.isEmpty
                ? (Self.text(item["subtitle"]) ?? "")
                : artistNames.joined(separator: ", ")
            let durationObject = Self.dictionary(item["duration"]) ?? [:]
            let duration = Self.integer(item["durationMs"])
                ?? Self.integer(item["duration_ms"])
                ?? Self.integer(durationObject["totalMilliseconds"])
                ?? Self.integer(durationObject["milliseconds"])
                ?? Self.integer(durationObject["ms"])
                ?? Self.integer(durationObject["total_seconds"]).map { $0 * 1000 }
            let albumObject = Self.dictionary(item["album"]) ?? Self.dictionary(item["albumOfTrack"]) ?? [:]
            let album = Self.text(item["albumName"]) ?? Self.text(albumObject["name"])
            let spotifyID = Self.text(item["uri"] ) ?? Self.text(item["id"])

            return SpotifySourceTrack(
                position: position,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                artistText: artistText,
                artistNames: artistNames,
                durationMilliseconds: duration,
                album: album,
                spotifyID: spotifyID?.components(separatedBy: CharacterSet(charactersIn: ":/")).last,
                metadataAvailable: metadataAvailable
            )
        }

        guard !parsedTracks.isEmpty else { throw SpotifyPlaylistImportError.noTracks }
        return (title, description, artworkURL, parsedTracks)
    }

    private nonisolated static func resolve(_ source: SpotifySourceTrack) async -> SpotifyPlaylistImportEntry {
        guard source.metadataAvailable else {
            return SpotifyPlaylistImportEntry(
                source: source,
                matchedTrack: nil,
                lookupFailure: "Spotify tidak menyediakan metadata judul untuk lagu ini."
            )
        }

        let primaryArtist = source.leadArtist.trimmingCharacters(in: .whitespacesAndNewlines)
        let queries = [
            "\(source.title) \(primaryArtist)".trimmingCharacters(in: .whitespacesAndNewlines),
            "\(source.title) \(source.artistText)".trimmingCharacters(in: .whitespacesAndNewlines)
        ].filter { !$0.isEmpty }.reduce(into: [String]()) { result, query in
            if !result.contains(where: { $0.caseInsensitiveCompare(query) == .orderedSame }) {
                result.append(query)
            }
        }

        var candidates: [String: CatalogItem] = [:]
        for query in queries {
            do {
                let page = try await MusicCatalogService.shared.searchPage(
                    query: query,
                    filter: .songs
                )
                for candidate in page.items where candidate.kind == .song && candidate.canSaveAsTrack {
                    candidates[candidate.id] = candidate
                }
            } catch {
                return SpotifyPlaylistImportEntry(
                    source: source,
                    matchedTrack: nil,
                    lookupFailure: error.localizedDescription
                )
            }
        }

        let reliableMatches = candidates.values.filter { Self.isReliableMatch(source, candidate: $0) }
        guard reliableMatches.count == 1, let candidate = reliableMatches.first else {
            return SpotifyPlaylistImportEntry(
                source: source,
                matchedTrack: nil,
                lookupFailure: nil
            )
        }

        return SpotifyPlaylistImportEntry(
            source: source,
            matchedTrack: candidate.asMusicTrack(),
            lookupFailure: nil
        )
    }

    private nonisolated static func isReliableMatch(
        _ source: SpotifySourceTrack,
        candidate: CatalogItem
    ) -> Bool {
        let expectedTitle = normalized(source.title)
        guard !expectedTitle.isEmpty,
              normalized(candidate.title) == expectedTitle,
              let sourceDuration = source.durationMilliseconds,
              let candidateDuration = candidate.durationSeconds else {
            return false
        }

        let spotifySeconds = Int((Double(sourceDuration) / 1000).rounded())
        guard abs(spotifySeconds - candidateDuration) <= 5 else { return false }

        let expectedArtist = normalized(source.leadArtist)
        guard !expectedArtist.isEmpty else { return false }

        if !candidate.artists.isEmpty {
            return candidate.artists.contains { normalized($0.name) == expectedArtist }
        }
        return normalized(candidate.artist) == normalized(source.artistText)
    }

    private nonisolated static func normalized(_ value: String) -> String {
        let folded = value.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        let scalars = folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        return String(String.UnicodeScalarView(scalars))
    }

    private nonisolated static func dictionary(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    private nonisolated static func nested(_ value: Any?, _ keys: [String]) -> Any? {
        keys.reduce(value) { current, key in
            (current as? [String: Any])?[key]
        }
    }

    private nonisolated static func text(_ value: Any?) -> String? {
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let object = value as? [String: Any] {
            return text(object["name"]) ?? text(object["text"])
        }
        return nil
    }

    private nonisolated static func integer(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string) }
        return nil
    }

    private nonisolated static func playlistArtworkURL(_ entity: [String: Any]) -> URL? {
        let sources = (nested(entity, ["coverArt", "sources"]) as? [[String: Any]])
            ?? (nested(entity, ["images", "items"]) as? [[String: Any]])
            ?? (entity["images"] as? [[String: Any]])
            ?? []
        let urls = sources.compactMap { text($0["url"]) }.compactMap(URL.init(string:))
        return urls.last(where: { $0.scheme?.lowercased() == "https" })
    }
}
