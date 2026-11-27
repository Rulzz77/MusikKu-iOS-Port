import Foundation

enum CatalogItemKind: String, Hashable {
    case song
    case video
    case album
    case artist
    case playlist
    case other
}

enum CatalogSearchFilter: String, CaseIterable, Identifiable {
    case all
    case songs
    case videos
    case albums
    case artists
    case playlists

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Semua"
        case .songs: return "Lagu"
        case .videos: return "Video"
        case .albums: return "Album"
        case .artists: return "Artis"
        case .playlists: return "Playlist"
        }
    }

    /// Same WEB_REMIX filter parameters used by MusikKu Android.
    /// The Songs tab intentionally requests the unfiltered result and filters
    /// playable song rows locally, matching YtMusicRepository.searchPage.
    var requestParams: String? {
        switch self {
        case .all, .songs: return nil
        case .videos: return "EgWKAQIQAWoKEAkQChAFEAMQBA=="
        case .albums: return "EgWKAQIYAWoKEAkQChAFEAMQBA=="
        case .artists: return "EgWKAQIgAWoKEAkQChAFEAMQBA=="
        case .playlists: return "EgWKAQIoAWoKEAkQChAFEAMQBA=="
        }
    }
}

struct CatalogArtist: Hashable {
    let name: String
    let browseID: String?
}

struct CatalogItem: Identifiable, Hashable {
    let id: String
    let kind: CatalogItemKind
    let title: String
    let subtitle: String
    let artist: String
    let artists: [CatalogArtist]
    let albumName: String?
    let albumBrowseID: String?
    let browseID: String?
    let artworkURL: URL?
    let durationSeconds: Int?
    let isExplicit: Bool
    let isVideo: Bool

    var canSaveAsTrack: Bool {
        kind == .song || kind == .video
    }

    func asMusicTrack() -> MusicTrack {
        MusicTrack(
            id: id,
            title: title,
            artist: artist,
            album: albumName,
            artworkURL: artworkURL,
            streamURL: nil,
            durationSeconds: durationSeconds,
            youtubeVideoID: canSaveAsTrack ? id : nil
        )
    }
}


struct CatalogHomeShelf: Identifiable, Hashable {
    let title: String
    let subtitle: String
    let items: [CatalogItem]

    var id: String {
        "\(title)|\(items.first?.id ?? "empty")"
    }
}


struct CatalogBrowsePage: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let artworkURL: URL?
    let tracks: [CatalogItem]
    let shelves: [CatalogHomeShelf]
}
