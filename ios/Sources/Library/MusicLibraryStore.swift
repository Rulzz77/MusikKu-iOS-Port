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

struct MusicListeningEntry: Identifiable, Codable, Hashable {
    let track: MusicTrack
    var playCount: Int
    var lastPlayedAt: Date

    var id: String { track.id }
}

@MainActor
final class MusicLibraryStore: ObservableObject {
    @Published private(set) var favorites: [MusicTrack] = []
    @Published private(set) var playlists: [MusicPlaylist] = []
    @Published private(set) var listeningHistory: [MusicListeningEntry] = []
    @Published private(set) var recentSearches: [String] = []

    private let defaults: UserDefaults
    private let favoritesKey = "musikku.library.favorites.v1"
    private let playlistsKey = "musikku.library.playlists.v1"
    private let historyKey = "musikku.library.history.v1"
    private let searchHistoryKey = "musikku.library.search-history.v1"

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

        if let data = defaults.data(forKey: historyKey),
           let saved = try? JSONDecoder().decode([MusicListeningEntry].self, from: data) {
            listeningHistory = saved.sorted { $0.lastPlayedAt > $1.lastPlayedAt }
        }

        if let data = defaults.data(forKey: searchHistoryKey),
           let saved = try? JSONDecoder().decode([String].self, from: data) {
            recentSearches = saved
        }
    }

    var recentlyPlayed: [MusicTrack] {
        listeningHistory.sorted { $0.lastPlayedAt > $1.lastPlayedAt }.map(\.track)
    }

    /// Local Mix seed: songs ranked by actual play count, most-played first.
    var mostPlayed: [MusicTrack] {
        listeningHistory
            .sorted {
                if $0.playCount == $1.playCount {
                    return $0.lastPlayedAt > $1.lastPlayedAt
                }
                return $0.playCount > $1.playCount
            }
            .map(\.track)
    }

    func recordPlay(_ track: MusicTrack) {
        if let index = listeningHistory.firstIndex(where: { $0.track.id == track.id }) {
            var entry = listeningHistory.remove(at: index)
            entry = MusicListeningEntry(
                track: track,
                playCount: entry.playCount + 1,
                lastPlayedAt: Date()
            )
            listeningHistory.insert(entry, at: 0)
        } else {
            listeningHistory.insert(
                MusicListeningEntry(track: track, playCount: 1, lastPlayedAt: Date()),
                at: 0
            )
        }

        if listeningHistory.count > 200 {
            listeningHistory = Array(listeningHistory.prefix(200))
        }
        persist()
    }

    func clearHistory() {
        listeningHistory = []
        persist()
    }

    func recordSearch(_ rawQuery: String) {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        recentSearches = Array(
            ([query] + recentSearches.filter { $0.caseInsensitiveCompare(query) != .orderedSame })
                .prefix(20)
        )
        if let data = try? JSONEncoder().encode(recentSearches) {
            defaults.set(data, forKey: searchHistoryKey)
        }
    }

    func removeSearch(_ query: String) {
        recentSearches.removeAll { $0 == query }
        if let data = try? JSONEncoder().encode(recentSearches) {
            defaults.set(data, forKey: searchHistoryKey)
        }
    }

    func clearSearchHistory() {
        recentSearches = []
        defaults.removeObject(forKey: searchHistoryKey)
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
        if let historyData = try? JSONEncoder().encode(listeningHistory) {
            defaults.set(historyData, forKey: historyKey)
        }
    }
}
