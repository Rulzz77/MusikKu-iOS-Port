import Foundation

/// Platform-neutral track data passed from an authorized catalog provider to the player.
struct MusicTrack: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var artist: String
    var album: String?
    var artworkURL: URL?
    var streamURL: URL?
    var durationSeconds: Int?
    var youtubeVideoID: String?

    init(
        id: String,
        title: String,
        artist: String,
        album: String? = nil,
        artworkURL: URL? = nil,
        streamURL: URL? = nil,
        durationSeconds: Int? = nil,
        youtubeVideoID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
        self.streamURL = streamURL
        self.durationSeconds = durationSeconds
        self.youtubeVideoID = youtubeVideoID
    }
}
