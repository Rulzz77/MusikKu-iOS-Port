import Foundation

enum MusicCatalogError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case emptyQuery

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Alamat katalog musik tidak valid."
        case .invalidResponse:
            return "Respons katalog musik tidak dapat dibaca."
        case .httpStatus(let status):
            return "Katalog musik mengembalikan HTTP \(status). Coba lagi nanti."
        case .emptyQuery:
            return "Masukkan judul lagu, artis, atau album terlebih dahulu."
        }
    }
}

/// Read-only, anonymous WEB_REMIX catalogue client matching the request shape
/// used by MusikKu Android's Innertube.postMusicAnonymous("search").
///
/// This first native adapter deliberately does not send Google cookies or
/// account credentials. Account/library writes and audio stream extraction
/// remain separate integrations and are not implied by a successful search.
actor MusicCatalogService {
    static let shared = MusicCatalogService()

    private let session: URLSession
    private var cachedClientVersion: String?
    private let fallbackClientVersion = "1.20250101.01.00"
    private let musicOrigin = "https://music.youtube.com"
    private let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(query rawQuery: String, filter: CatalogSearchFilter) async throws -> [CatalogItem] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { throw MusicCatalogError.emptyQuery }

        let locale = Locale.current
        let language = locale.language.languageCode?.identifier ?? "en"
        let region = locale.region?.identifier ?? "US"
        let clientVersion = await resolveClientVersion()

        guard var components = URLComponents(string: "\(musicOrigin)/youtubei/v1/search") else {
            throw MusicCatalogError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "prettyPrint", value: "false"),
            URLQueryItem(name: "hl", value: language)
        ]
        guard let url = components.url else { throw MusicCatalogError.invalidURL }

        var client: [String: Any] = [
            "clientName": "WEB_REMIX",
            "clientVersion": clientVersion,
            "hl": language,
            "gl": region
        ]
        client["utcOffsetMinutes"] = TimeZone.current.secondsFromGMT() / 60

        var body: [String: Any] = [
            "context": [
                "client": client,
                "user": ["lockedSafetyMode": false],
                "request": ["useSsl": true]
            ],
            "query": query
        ]
        if let params = filter.requestParams {
            body["params"] = params
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(language, forHTTPHeaderField: "Accept-Language")
        request.setValue(musicOrigin, forHTTPHeaderField: "Origin")
        request.setValue(musicOrigin, forHTTPHeaderField: "X-Origin")
        request.setValue("\(musicOrigin)/", forHTTPHeaderField: "Referer")
        request.setValue("67", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(clientVersion, forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MusicCatalogError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw MusicCatalogError.httpStatus(http.statusCode)
        }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MusicCatalogError.invalidResponse
        }

        let parsed = parseSearch(root)
        return parsed.filter { item in
            switch filter {
            case .all: return true
            case .songs: return item.kind == .song
            case .videos: return item.kind == .video
            case .albums: return item.kind == .album
            case .artists: return item.kind == .artist
            case .playlists: return item.kind == .playlist
            }
        }
        .uniqued(by: { "\($0.kind.rawValue):\($0.id)" })
    }

    func browsePage(browseID: String, params: String? = nil) async throws -> CatalogBrowsePage {
        let locale = Locale.current
        let language = locale.language.languageCode?.identifier ?? "en"
        let region = locale.region?.identifier ?? "US"
        let clientVersion = await resolveClientVersion()

        guard var components = URLComponents(string: "\(musicOrigin)/youtubei/v1/browse") else {
            throw MusicCatalogError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "prettyPrint", value: "false"),
            URLQueryItem(name: "hl", value: language)
        ]
        guard let url = components.url else { throw MusicCatalogError.invalidURL }

        var body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": clientVersion,
                    "hl": language,
                    "gl": region
                ],
                "user": ["lockedSafetyMode": false],
                "request": ["useSsl": true]
            ],
            "browseId": browseID
        ]
        if let params, !params.isEmpty {
            body["params"] = params
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(language, forHTTPHeaderField: "Accept-Language")
        request.setValue(musicOrigin, forHTTPHeaderField: "Origin")
        request.setValue(musicOrigin, forHTTPHeaderField: "X-Origin")
        request.setValue("\(musicOrigin)/", forHTTPHeaderField: "Referer")
        request.setValue("67", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(clientVersion, forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MusicCatalogError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw MusicCatalogError.httpStatus(http.statusCode)
        }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MusicCatalogError.invalidResponse
        }
        return parseBrowsePage(root, browseID: browseID)
    }


    func moodAndGenres() async throws -> [CatalogMoodGenre] {
        let page = try await browsePage(browseID: "FEmusic_moods_and_genres")
        return page.moodGenres
    }

    private func parseBrowsePage(_ root: [String: Any], browseID: String) -> CatalogBrowsePage {
        let headerNames = [
            "musicResponsiveHeaderRenderer",
            "musicImmersiveHeaderRenderer",
            "musicDetailHeaderRenderer",
            "musicEditablePlaylistDetailHeaderRenderer"
        ]
        let header = headerNames
            .compactMap { Self.collectRenderers(root, named: $0).first }
            .first

        let title = Self.runsText(header?["title"]).nonEmpty ?? browseID
        let strapline = Self.runsText(header?["strapline"])
        let subtitle = Self.runsText(header?["subtitle"])
        let headerSubtitle = [strapline, subtitle]
            .filter { !$0.isEmpty }
            .uniqued(by: { $0 })
            .joined(separator: " • ")

        let thumbnailRenderer = Self.collectRenderers(header ?? root, named: "musicThumbnailRenderer").first
        let thumbnailList = Self.nested(thumbnailRenderer, "thumbnail", "thumbnails") as? [[String: Any]]
            ?? Self.nested(thumbnailRenderer, "thumbnail", "musicThumbnailRenderer", "thumbnail", "thumbnails") as? [[String: Any]]
            ?? []
        let artworkURL = Self.bestThumbnailURL(thumbnailList)

        let tracks = Self.collectRenderers(root, named: "musicResponsiveListItemRenderer")
            .compactMap { parseTrack($0) }
            .uniqued(by: { $0.id })

        let shelves = Self.collectRenderers(root, named: "musicCarouselShelfRenderer")
            .compactMap { parseCarouselShelf($0) }

        return CatalogBrowsePage(
            id: browseID,
            title: title,
            subtitle: headerSubtitle,
            artworkURL: artworkURL,
            tracks: tracks,
            shelves: shelves,
            moodGenres: parseMoodGenres(root)
        )
    }

    private func parseMoodGenres(_ root: [String: Any]) -> [CatalogMoodGenre] {
        guard
            let tabs = Self.nested(root, "contents", "singleColumnBrowseResultsRenderer", "tabs") as? [Any],
            let firstTab = tabs.first,
            let sections = Self.nested(firstTab, "tabRenderer", "content", "sectionListRenderer", "contents") as? [Any]
        else { return [] }

        var seen = Set<String>()
        var result: [CatalogMoodGenre] = []

        for section in sections {
            guard
                let grid = Self.nested(section, "gridRenderer") as? [String: Any],
                let items = grid["items"] as? [Any]
            else { continue }

            let sectionTitle = Self.runsText(Self.nested(grid, "header", "gridHeaderRenderer", "title"))
            if sectionTitle.localizedCaseInsensitiveCompare("For you") == .orderedSame {
                continue
            }

            for entry in items {
                guard
                    let button = Self.nested(entry, "musicNavigationButtonRenderer") as? [String: Any],
                    let clickEndpoint = Self.nested(button, "clickCommand", "browseEndpoint") as? [String: Any]
                        ?? Self.nested(button, "navigationEndpoint", "browseEndpoint") as? [String: Any],
                    let browseID = clickEndpoint["browseId"] as? String,
                    !browseID.isEmpty
                else { continue }

                let title = Self.runsText(button["buttonText"])
                guard !title.isEmpty else { continue }

                let params = clickEndpoint["params"] as? String
                let identity = "\(browseID)|\(params ?? "")"
                guard seen.insert(identity).inserted else { continue }

                let stripeNumber = Self.nested(button, "solid", "leftStripeColor") as? NSNumber
                let stripeString = Self.nested(button, "solid", "leftStripeColor") as? String
                let stripeColor = stripeNumber?.uint32Value ?? stripeString.flatMap(UInt32.init)

                result.append(
                    CatalogMoodGenre(
                        title: title,
                        browseID: browseID,
                        params: params,
                        stripeColor: stripeColor
                    )
                )
            }
        }
        return result
    }

    private func parseCarouselShelf(_ carousel: [String: Any]) -> CatalogHomeShelf? {
        let header = Self.nested(carousel, "header", "musicCarouselShelfBasicHeaderRenderer")
        let title = Self.runsText(Self.nested(header, "title"))
        let subtitle = Self.runsText(Self.nested(header, "strapline"))
        let contents = carousel["contents"] as? [Any] ?? []
        let items = contents.compactMap { entry -> CatalogItem? in
            if let twoRow = Self.nested(entry, "musicTwoRowItemRenderer") as? [String: Any] {
                return parseTwoRowItem(twoRow)
            }
            if let row = Self.nested(entry, "musicResponsiveListItemRenderer") as? [String: Any] {
                return parseBrowseItem(row) ?? parseTrack(row)
            }
            return nil
        }
        guard !title.isEmpty, !items.isEmpty else { return nil }
        return CatalogHomeShelf(title: title, subtitle: subtitle, items: items)
    }

    func homeFeed() async throws -> [CatalogHomeShelf] {
        let locale = Locale.current
        let language = locale.language.languageCode?.identifier ?? "en"
        let region = locale.region?.identifier ?? "US"
        let clientVersion = await resolveClientVersion()

        guard var components = URLComponents(string: "\(musicOrigin)/youtubei/v1/browse") else {
            throw MusicCatalogError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "prettyPrint", value: "false"),
            URLQueryItem(name: "hl", value: language)
        ]
        guard let url = components.url else { throw MusicCatalogError.invalidURL }

        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": clientVersion,
                    "hl": language,
                    "gl": region
                ],
                "user": ["lockedSafetyMode": false],
                "request": ["useSsl": true]
            ],
            "browseId": "FEmusic_home"
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(language, forHTTPHeaderField: "Accept-Language")
        request.setValue(musicOrigin, forHTTPHeaderField: "Origin")
        request.setValue(musicOrigin, forHTTPHeaderField: "X-Origin")
        request.setValue("\(musicOrigin)/", forHTTPHeaderField: "Referer")
        request.setValue("67", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(clientVersion, forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MusicCatalogError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw MusicCatalogError.httpStatus(http.statusCode)
        }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MusicCatalogError.invalidResponse
        }
        return parseHome(root)
    }

    private func parseHome(_ root: [String: Any]) -> [CatalogHomeShelf] {
        guard
            let tabs = Self.nested(root, "contents", "singleColumnBrowseResultsRenderer", "tabs") as? [Any],
            let firstTab = tabs.first,
            let sections = Self.nested(firstTab, "tabRenderer", "content", "sectionListRenderer", "contents") as? [Any]
        else { return [] }

        return sections.enumerated().compactMap { index, section in
            if let carousel = Self.nested(section, "musicCarouselShelfRenderer") as? [String: Any] {
                let header = Self.nested(carousel, "header", "musicCarouselShelfBasicHeaderRenderer")
                let title = Self.runsText(Self.nested(header, "title"))
                let subtitle = Self.runsText(Self.nested(header, "strapline"))
                let content = carousel["contents"] as? [Any] ?? []
                let items = content.compactMap { entry -> CatalogItem? in
                    if let twoRow = Self.nested(entry, "musicTwoRowItemRenderer") as? [String: Any] {
                        return parseTwoRowItem(twoRow)
                    }
                    if let responsive = Self.nested(entry, "musicResponsiveListItemRenderer") as? [String: Any] {
                        return parseBrowseItem(responsive) ?? parseTrack(responsive)
                    }
                    return nil
                }
                guard !title.isEmpty, !items.isEmpty else { return nil }
                return CatalogHomeShelf(title: title, subtitle: subtitle, items: items)
            }

            if let plain = Self.nested(section, "musicShelfRenderer") as? [String: Any] {
                let title = Self.runsText(plain["title"])
                let content = plain["contents"] as? [Any] ?? []
                let items = content.compactMap { entry -> CatalogItem? in
                    guard let row = Self.nested(entry, "musicResponsiveListItemRenderer") as? [String: Any] else {
                        return nil
                    }
                    return parseTrack(row)
                }
                guard !items.isEmpty else { return nil }
                return CatalogHomeShelf(
                    title: title.isEmpty ? "Musik untuk kamu \(index + 1)" : title,
                    subtitle: "",
                    items: items
                )
            }
            return nil
        }
    }

    private func parseTwoRowItem(_ renderer: [String: Any]) -> CatalogItem? {
        let title = Self.runsText(renderer["title"])
        guard !title.isEmpty else { return nil }

        let endpoint = Self.dictionary(renderer["navigationEndpoint"]) ?? [:]
        let rawBrowseID = Self.string(Self.nested(endpoint, "browseEndpoint", "browseId"))
        let resolvedBrowseID = rawBrowseID?.hasPrefix("MPED") == true ? nil : rawBrowseID
        let videoID: String?
        if let watchID = Self.string(Self.nested(endpoint, "watchEndpoint", "videoId")) {
            videoID = watchID
        } else if let rawBrowseID, rawBrowseID.hasPrefix("MPED") {
            videoID = String(rawBrowseID.dropFirst(4))
        } else {
            videoID = nil
        }
        let subtitle = Self.runsText(renderer["subtitle"])
        let pageType = Self.string(Self.nested(endpoint, "browseEndpoint", "browseEndpointContextSupportedConfigs", "browseEndpointContextMusicConfig", "pageType")) ?? ""

        if pageType.contains("PODCAST") || subtitle.localizedCaseInsensitiveContains(" • Episode") {
            return nil
        }

        let thumbnails = Self.nested(renderer, "thumbnailRenderer", "musicThumbnailRenderer", "thumbnail", "thumbnails") as? [[String: Any]] ?? []
        let image = Self.bestThumbnailURL(thumbnails)
        let isVideo = resolvedBrowseID == nil && videoID != nil && (
            Self.thumbnailArrayIsWide(thumbnails) ||
            (Self.string(renderer["aspectRatio"])?.contains("16_9") ?? false)
        )

        let kind: CatalogItemKind
        if resolvedBrowseID != nil {
            if pageType.contains("ALBUM") { kind = .album }
            else if pageType.contains("ARTIST") { kind = .artist }
            else if pageType.contains("PLAYLIST") { kind = .playlist }
            else { kind = .other }
        } else if isVideo {
            kind = .video
        } else {
            kind = .song
        }

        guard let id = resolvedBrowseID ?? videoID else { return nil }
        let parts = subtitle.components(separatedBy: " • ").filter { !$0.isEmpty }
        let duration = parts.first(where: Self.isDuration).flatMap(Self.durationSeconds)
        let artist = parts.first {
            !["song", "video", "album", "single", "ep", "artist", "playlist", "episode"].contains($0.lowercased()) &&
            !Self.isDuration($0) && !Self.isYear($0)
        } ?? subtitle

        return CatalogItem(
            id: id,
            kind: kind,
            title: title,
            subtitle: subtitle,
            artist: artist,
            artists: [],
            albumName: kind == .album ? title : nil,
            albumBrowseID: kind == .album ? resolvedBrowseID : nil,
            browseID: resolvedBrowseID,
            artworkURL: image,
            durationSeconds: duration,
            isExplicit: Self.containsExplicitBadge(renderer),
            isVideo: isVideo
        )
    }

    private func resolveClientVersion() async -> String {
        if let cachedClientVersion { return cachedClientVersion }

        guard let url = URL(string: "\(musicOrigin)/") else {
            return fallbackClientVersion
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        do {
            let (data, _) = try await session.data(for: request)
            guard let html = String(data: data, encoding: .utf8),
                  let version = Self.firstCapture(
                    pattern: #""INNERTUBE_CLIENT_VERSION"\s*:\s*"([^"]+)""#,
                    in: html
                  ) else {
                return fallbackClientVersion
            }
            cachedClientVersion = version
            return version
        } catch {
            return fallbackClientVersion
        }
    }

    private func parseSearch(_ root: [String: Any]) -> [CatalogItem] {
        let renderers = Self.collectRenderers(root, named: "musicResponsiveListItemRenderer")
        var items: [CatalogItem] = []

        // The Android parser tests browse rows before track rows because an
        // album row can also carry a videoId in its play overlay.
        for renderer in renderers {
            if let browse = parseBrowseItem(renderer) {
                items.append(browse)
            } else if let track = parseTrack(renderer) {
                items.append(track)
            }
        }
        return items
    }

    private func parseBrowseItem(_ renderer: [String: Any]) -> CatalogItem? {
        guard
            let endpoint = Self.dictionary(renderer["navigationEndpoint"])?["browseEndpoint"] as? [String: Any],
            let browseID = endpoint["browseId"] as? String
        else { return nil }

        let pageConfig = Self.dictionary(Self.dictionary(endpoint["browseEndpointContextSupportedConfigs"])?["browseEndpointContextMusicConfig"])
        let pageType = pageConfig?["pageType"] as? String ?? ""
        let kind: CatalogItemKind
        if pageType.contains("ALBUM") {
            kind = .album
        } else if pageType.contains("ARTIST") {
            kind = .artist
        } else if pageType.contains("PLAYLIST") {
            kind = .playlist
        } else {
            kind = .other
        }

        let columns = renderer["flexColumns"] as? [Any] ?? []
        let title = Self.runsText(Self.nested(columns[safe: 0], "musicResponsiveListItemFlexColumnRenderer", "text"))
        guard !title.isEmpty else { return nil }
        let subtitle = Self.runsText(Self.nested(columns[safe: 1], "musicResponsiveListItemFlexColumnRenderer", "text"))
        if Self.looksLikeVideoCollection(title) || Self.looksLikeVideoCollection(subtitle) {
            return nil
        }

        return CatalogItem(
            id: browseID,
            kind: kind,
            title: title,
            subtitle: subtitle,
            artist: subtitle,
            artists: [],
            albumName: nil,
            albumBrowseID: nil,
            browseID: browseID,
            artworkURL: Self.thumbnailURL(renderer),
            durationSeconds: nil,
            isExplicit: Self.containsExplicitBadge(renderer),
            isVideo: false
        )
    }

    private func parseTrack(_ renderer: [String: Any]) -> CatalogItem? {
        let columns = renderer["flexColumns"] as? [Any] ?? []
        let titleObject = Self.nested(columns[safe: 0], "musicResponsiveListItemFlexColumnRenderer", "text")
        let title = Self.runsText(titleObject)
        guard !title.isEmpty else { return nil }

        let titleRuns = Self.dictionary(titleObject)?["runs"] as? [Any] ?? []
        let videoID =
            Self.string(Self.nested(renderer, "playlistItemData", "videoId")) ??
            Self.string(Self.nested(titleRuns.first, "navigationEndpoint", "watchEndpoint", "videoId")) ??
            Self.string(Self.nested(renderer, "overlay", "musicItemThumbnailOverlayRenderer", "content", "musicPlayButtonRenderer", "playNavigationEndpoint", "watchEndpoint", "videoId")) ??
            Self.string(Self.nested(renderer, "onTap", "watchEndpoint", "videoId")) ??
            Self.string(Self.nested(renderer, "navigationEndpoint", "watchEndpoint", "videoId"))
        guard let videoID, !videoID.isEmpty else { return nil }

        let subtitleObject = Self.nested(columns[safe: 1], "musicResponsiveListItemFlexColumnRenderer", "text")
        let subtitle = Self.runsText(subtitleObject)
        let parts = subtitle.components(separatedBy: " • ").filter { !$0.isEmpty }
        let typeWords = Set(["song", "video", "album", "single", "ep", "artist", "playlist", "episode", "podcast"])
        let durationText = parts.first(where: Self.isDuration)
            ?? (renderer["fixedColumns"] as? [Any])?.compactMap {
                Self.runsText(Self.nested($0, "musicResponsiveListItemFixedColumnRenderer", "text"))
            }.first(where: Self.isDuration)
        let artistPart = parts.first {
            !Self.isDuration($0) &&
            !Self.isYear($0) &&
            !typeWords.contains($0.lowercased()) &&
            !Self.isTally($0)
        }

        let subtitleRuns = Self.dictionary(subtitleObject)?["runs"] as? [Any] ?? []
        let artists = Self.artistCredits(subtitleRuns)
        let artist = artists.map(\.name).joined(separator: ", ")
            .nonEmpty ?? artistPart ?? "Unknown artist"

        let albumCredit = Self.browseCredit(subtitleRuns, pageType: "ALBUM")
        let durationSeconds = durationText.flatMap(Self.durationSeconds)
        let rowType = parts.first(where: { typeWords.contains($0.lowercased()) })?.lowercased()
        let isVideo = rowType == "video" || Self.thumbnailIsWide(renderer)

        return CatalogItem(
            id: videoID,
            kind: isVideo ? .video : .song,
            title: title,
            subtitle: subtitle,
            artist: artist,
            artists: artists,
            albumName: albumCredit?.name,
            albumBrowseID: albumCredit?.browseID,
            browseID: nil,
            artworkURL: Self.thumbnailURL(renderer),
            durationSeconds: durationSeconds,
            isExplicit: Self.containsExplicitBadge(renderer),
            isVideo: isVideo
        )
    }

    private static func collectRenderers(_ root: Any, named target: String) -> [[String: Any]] {
        var result: [[String: Any]] = []
        func walk(_ value: Any) {
            if let dictionary = value as? [String: Any] {
                for (key, child) in dictionary {
                    if key == target, let renderer = child as? [String: Any] {
                        result.append(renderer)
                    }
                    walk(child)
                }
            } else if let array = value as? [Any] {
                array.forEach(walk)
            }
        }
        walk(root)
        return result
    }

    private static func artistCredits(_ runs: [Any]) -> [CatalogArtist] {
        runs.compactMap { run -> CatalogArtist? in
            let object = run as? [String: Any] ?? [:]
            let name = object["text"] as? String ?? ""
            guard !name.isEmpty else { return nil }
            let browseID = string(nested(object, "navigationEndpoint", "browseEndpoint", "browseId"))
            let pageType = string(nested(object, "navigationEndpoint", "browseEndpoint", "browseEndpointContextSupportedConfigs", "browseEndpointContextMusicConfig", "pageType")) ?? ""
            return pageType.contains("ARTIST") ? CatalogArtist(name: name, browseID: browseID) : nil
        }
    }

    private static func browseCredit(_ runs: [Any], pageType target: String) -> (name: String, browseID: String?)? {
        for run in runs {
            let object = run as? [String: Any] ?? [:]
            let browse = nested(object, "navigationEndpoint", "browseEndpoint")
            let pageType = string(nested(browse, "browseEndpointContextSupportedConfigs", "browseEndpointContextMusicConfig", "pageType")) ?? ""
            guard pageType.contains(target), let name = object["text"] as? String, !name.isEmpty else { continue }
            return (name, string(nested(browse, "browseId")))
        }
        return nil
    }

    private static func bestThumbnailURL(_ thumbnails: [[String: Any]]) -> URL? {
        let best = thumbnails.max {
            let left = (($0["width"] as? Int) ?? 0) * (($0["height"] as? Int) ?? 0)
            let right = (($1["width"] as? Int) ?? 0) * (($1["height"] as? Int) ?? 0)
            return left < right
        }
        return (best?["url"] as? String).flatMap(URL.init(string:))
    }

    private static func thumbnailArrayIsWide(_ thumbnails: [[String: Any]]) -> Bool {
        guard let first = thumbnails.first else { return false }
        let width = first["width"] as? Double ?? Double(first["width"] as? Int ?? 0)
        let height = first["height"] as? Double ?? Double(first["height"] as? Int ?? 0)
        return height > 0 && width / height > 1.25
    }

    private static func thumbnailURL(_ renderer: [String: Any]) -> URL? {
        let nestedThumbs = nested(renderer, "thumbnail", "musicThumbnailRenderer", "thumbnail", "thumbnails")
            as? [[String: Any]]
        let ordinaryThumbs = nested(renderer, "thumbnail", "thumbnails") as? [[String: Any]]
        let thumbs = nestedThumbs ?? ordinaryThumbs ?? []
        let best = thumbs.max {
            let lhs = (($0["width"] as? Int) ?? 0) * (($0["height"] as? Int) ?? 0)
            let rhs = (($1["width"] as? Int) ?? 0) * (($1["height"] as? Int) ?? 0)
            return lhs < rhs
        }
        return (best?["url"] as? String).flatMap(URL.init(string:))
    }

    private static func thumbnailIsWide(_ renderer: [String: Any]) -> Bool {
        let thumbs = nested(renderer, "thumbnail", "musicThumbnailRenderer", "thumbnail", "thumbnails") as? [[String: Any]] ?? []
        guard let first = thumbs.first else { return false }
        let width = first["width"] as? Double ?? Double(first["width"] as? Int ?? 0)
        let height = first["height"] as? Double ?? Double(first["height"] as? Int ?? 0)
        return height > 0 && width / height > 1.25
    }

    private static func containsExplicitBadge(_ value: Any) -> Bool {
        if let dictionary = value as? [String: Any] {
            if let icon = dictionary["iconType"] as? String, icon == "EXPLICIT" { return true }
            if let text = dictionary["label"] as? String, text.localizedCaseInsensitiveContains("explicit") { return true }
            return dictionary.values.contains { containsExplicitBadge($0) }
        }
        if let array = value as? [Any] {
            return array.contains { containsExplicitBadge($0) }
        }
        return false
    }

    private static func runsText(_ value: Any?) -> String {
        guard let value else { return "" }
        if let string = value as? String { return string }
        guard let dictionary = value as? [String: Any] else { return "" }
        if let simple = dictionary["simpleText"] as? String { return simple }
        if let runs = dictionary["runs"] as? [Any] {
            return runs.compactMap { ($0 as? [String: Any])?["text"] as? String }.joined()
        }
        return ""
    }

    private static func nested(_ value: Any?, _ keys: String...) -> Any? {
        var current = value
        for key in keys {
            guard let dictionary = current as? [String: Any] else { return nil }
            current = dictionary[key]
        }
        return current
    }

    private static func dictionary(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    private static func string(_ value: Any?) -> String? {
        value as? String
    }

    private static func firstCapture(pattern: String, in value: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: value) else { return nil }
        return String(value[range])
    }

    private static func durationSeconds(_ value: String) -> Int? {
        let parts = value.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 || parts.count == 3 else { return nil }
        let seconds: Int
        if parts.count == 2 {
            seconds = parts[0] * 60 + parts[1]
        } else {
            seconds = parts[0] * 3600 + parts[1] * 60 + parts[2]
        }
        return seconds >= 0 ? seconds : nil
    }

    private static func isDuration(_ value: String) -> Bool {
        value.range(of: #"^\d{1,3}:\d{2}(?::\d{2})?$"#, options: .regularExpression) != nil
    }

    private static func isYear(_ value: String) -> Bool {
        value.range(of: #"^(19|20)\d{2}$"#, options: .regularExpression) != nil
    }

    private static func isTally(_ value: String) -> Bool {
        value.localizedCaseInsensitiveContains("views") ||
        value.localizedCaseInsensitiveContains("plays")
    }

    private static func looksLikeVideoCollection(_ value: String) -> Bool {
        value.localizedCaseInsensitiveContains("video")
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

private extension Array where Element: Hashable {
    func uniqued(by key: (Element) -> String) -> [Element] {
        var seen = Set<String>()
        return filter { seen.insert(key($0)).inserted }
    }
}
