import XCTest
@testable import MusikKu

final class SpotifyPlaylistImportServiceTests: XCTestCase {
    func testExtractsCanonicalPlaylistLink() {
        let playlistID = "37i9dQZF1DXcBWIGoYBM5M"

        XCTAssertEqual(
            SpotifyPlaylistImportService.extractPlaylistID(
                from: "https://open.spotify.com/playlist/\(playlistID)?si=share-token"
            ),
            playlistID
        )
    }

    func testExtractsLocaleAndSpotifyURIFormats() {
        let playlistID = "37i9dQZF1DXcBWIGoYBM5M"

        XCTAssertEqual(
            SpotifyPlaylistImportService.extractPlaylistID(
                from: "https://open.spotify.com/intl-id/playlist/\(playlistID)?si=share-token"
            ),
            playlistID
        )
        XCTAssertEqual(
            SpotifyPlaylistImportService.extractPlaylistID(from: "spotify:playlist:\(playlistID)"),
            playlistID
        )
    }

    func testRejectsLookalikeHostsAndMalformedIdentifiers() {
        XCTAssertNil(
            SpotifyPlaylistImportService.extractPlaylistID(
                from: "https://open.spotify.com.example.net/playlist/37i9dQZF1DXcBWIGoYBM5M"
            )
        )
        XCTAssertNil(
            SpotifyPlaylistImportService.extractPlaylistID(
                from: "https://example.com/playlist/37i9dQZF1DXcBWIGoYBM5M"
            )
        )
        XCTAssertNil(
            SpotifyPlaylistImportService.extractPlaylistID(from: "spotify:playlist:not-a-valid-id")
        )
    }
}

final class MusicLibraryStoreTests: XCTestCase {
    func testImportedPlaylistDeduplicatesAndPersistsTracks() async {
        let result = await MainActor.run { () -> (Int, [String]?, [String]?) in
            let suiteName = "MusikKuTests.\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: suiteName) else {
                XCTFail("Unable to create isolated UserDefaults suite")
                return (0, nil, nil)
            }
            defer { defaults.removePersistentDomain(forName: suiteName) }

            let first = MusicTrack(id: "video-1", title: "Song One", artist: "Artist")
            let second = MusicTrack(id: "video-2", title: "Song Two", artist: "Artist")
            let store = MusicLibraryStore(defaults: defaults)
            let importedCount = store.importPlaylist("Imported", tracks: [first, second, first])
            let savedIDs = store.playlists.first?.tracks.map(\.id)
            let restoredIDs = MusicLibraryStore(defaults: defaults).playlists.first?.tracks.map(\.id)
            return (importedCount, savedIDs, restoredIDs)
        }

        XCTAssertEqual(result.0, 2)
        XCTAssertEqual(result.1, ["video-1", "video-2"])
        XCTAssertEqual(result.2, ["video-1", "video-2"])
    }

    func testSmartPlaylistFiltersByPlayCountAndDuration() async {
        let result = await MainActor.run { () -> [String] in
            let suiteName = "MusikKuTests.\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: suiteName) else {
                XCTFail("Unable to create isolated UserDefaults suite")
                return []
            }
            defer { defaults.removePersistentDomain(forName: suiteName) }

            let matching = MusicTrack(
                id: "matching",
                title: "Long Track",
                artist: "Example Artist",
                durationSeconds: 240,
                youtubeVideoID: "abcdefghijk"
            )
            let tooShort = MusicTrack(
                id: "short",
                title: "Short Track",
                artist: "Example Artist",
                durationSeconds: 90,
                youtubeVideoID: "lmnopqrstuv"
            )
            let store = MusicLibraryStore(defaults: defaults)
            store.recordPlay(matching)
            store.recordPlay(matching)
            store.recordPlay(tooShort)
            store.recordPlay(tooShort)

            let rule = MusicSmartPlaylistRule(
                name: "Frequent long tracks",
                artistContains: "example",
                minimumPlays: 2,
                sort: .mostPlayed,
                minimumDurationMinutes: 3,
                maximumDurationMinutes: 5,
                matchMode: .all
            )
            return store.tracks(for: rule).map(\.id)
        }

        XCTAssertEqual(result, ["matching"])
    }
}


final class MusikKuErrorMessageTests: XCTestCase {
    func testMapsOfflineNetworkErrorToIndonesianMessage() {
        XCTAssertEqual(
            MusikKuErrorMessage.indonesianMessage(
                for: URLError(.notConnectedToInternet),
                fallback: "Fallback"
            ),
            "Tidak dapat terhubung ke internet. Periksa koneksi lalu coba lagi."
        )
    }

    func testMapsTimeoutToIndonesianMessage() {
        XCTAssertEqual(
            MusikKuErrorMessage.indonesianMessage(
                for: URLError(.timedOut),
                fallback: "Fallback"
            ),
            "Koneksi terlalu lama. Coba lagi."
        )
    }

    func testUsesScreenSpecificFallbackForUnexpectedError() {
        let unexpected = NSError(domain: "MusikKuTests", code: 1)
        XCTAssertEqual(
            MusikKuErrorMessage.indonesianMessage(
                for: unexpected,
                fallback: "Katalog belum dapat dimuat."
            ),
            "Katalog belum dapat dimuat."
        )
    }
}


extension MusikKuErrorMessageTests {
    func testMapsUnderlyingNetworkErrorFromPlayerFailure() {
        let wrappedPlayerError = NSError(
            domain: "AVFoundationErrorDomain",
            code: -11800,
            userInfo: [NSUnderlyingErrorKey: URLError(.timedOut)]
        )

        XCTAssertEqual(
            MusikKuErrorMessage.indonesianMessage(
                for: wrappedPlayerError,
                fallback: "Sumber audio tidak dapat diputar."
            ),
            "Koneksi terlalu lama. Coba lagi."
        )
    }
}
