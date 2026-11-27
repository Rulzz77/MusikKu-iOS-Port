import Combine
import Foundation

struct MusicPlaylist: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var tracks: [MusicTrack]
    let createdAt: Date

    init(id: UUID = UUID(), name: String, tracks: [MusicTrack] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.tracks = tracks
        self.createdAt = createdAt
    }
}

@MainActor
final class MusicLibraryStore: ObservableObject {
    @Published private(set) var favorites: [MusicTrack] = []
    @Published private(set) var playlists: [MusicPlaylist] = []

    private let defaults: UserDefaults
    private let favoritesKey = "musikku.library.favorites.v1"
    private let playlistsKey = "musikku.library.playlists.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: favoritesKey),
           let saved = try? JSONDecoder().decode([MusicTrack].self, from: data) {
            favorites = saved
        }

        if let data = defaults.data(forKey: playlistsKey),
           let saved = try? JSONDecoder().decode([MusicPlaylist].self, from: data) {
            playlists = saved
        }
    }

    func isFavorite(_ track: MusicTrack) -> Bool {
        favorites.contains { $0.id == track.id }
    }

    func toggleFavorite(_ track: MusicTrack) {
        if let index = favorites.firstIndex(where: { $0.id == track.id }) {
            favorites.remove(at: index)
        } else {
            favorites.insert(track, at: 0)
        }
        persist()
    }

    @discardableResult
    func createPlaylist(_ rawName: String) -> Bool {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }

        playlists.insert(MusicPlaylist(name: name), at: 0)
        persist()
        return true
    }

    func deletePlaylist(id: UUID) {
        playlists.removeAll { $0.id == id }
        persist()
    }

    func add(_ track: MusicTrack, to playlistID: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        guard !playlists[index].tracks.contains(where: { $0.id == track.id }) else { return }
        playlists[index].tracks.append(track)
        persist()
    }

    func remove(_ track: MusicTrack, from playlistID: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[index].tracks.removeAll { $0.id == track.id }
        persist()
    }

    private func persist() {
        if let favoritesData = try? JSONEncoder().encode(favorites) {
            defaults.set(favoritesData, forKey: favoritesKey)
        }
        if let playlistsData = try? JSONEncoder().encode(playlists) {
            defaults.set(playlistsData, forKey: playlistsKey)
        }
    }
}
