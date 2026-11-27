import AVFoundation
import Combine
import MediaPlayer
import UIKit
import MusikKuResolverKit

@MainActor
final class PlaybackManager: ObservableObject {
    @Published private(set) var currentTrack: MusicTrack?
    @Published private(set) var playbackStartID = UUID()
    @Published private(set) var isPlaying = false
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var queue: [MusicTrack] = []
    @Published private(set) var isShuffleEnabled = false
    @Published private(set) var isRepeatEnabled = false
    @Published private(set) var isResolving = false
    @Published private(set) var isBuffering = false
    @Published var errorMessage: String?

    private var currentQueueIndex: Int?
    var currentQueueTrackIndex: Int? { currentQueueIndex }

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var observedPlayer: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var notificationObservers: [NSObjectProtocol] = []
    private var itemStatusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var shouldResumeAfterInterruption = false
    private var resolveTask: Task<Void, Never>?
    private let streamResolver = MusikKuAudioResolver()
    private var artworkTask: Task<Void, Never>?
    private var loadedArtworkURL: URL?
    private var loadedArtwork: UIImage?

    init() {
        configureRemoteCommands()
        configureAudioSessionNotifications()

        // Warm the remote player config and cipher cache before the first tap.
        // This is best-effort: playback can still attempt resolution if warm-up fails.
        Task { [weak self] in
            guard let self else { return }
            try? await self.streamResolver.prewarm(language: "id", region: "ID")
        }
    }

    /// Starts one track. The stream URL must come from a provider authorized for this app.
    func play(_ track: MusicTrack) {
        playQueue([track], startingAt: 0)
    }

    /// Replaces the current queue and starts the selected track.
    func playQueue(_ tracks: [MusicTrack], startingAt index: Int = 0) {
        guard !tracks.isEmpty else {
            queue = []
            currentQueueIndex = nil
            resolveTask?.cancel()
            resolveTask = nil
            isResolving = false
            player?.pause()
            detachPlaybackObservers()
            player = nil
            currentTrack = nil
            isPlaying = false
            isBuffering = false
            position = 0
            duration = 0
            updateNowPlaying()
            return
        }

        queue = tracks
        currentQueueIndex = min(max(index, 0), tracks.count - 1)
        startTrack(queue[currentQueueIndex ?? 0])
    }

    /// Adds a track after the current queue. If playback is empty, it starts immediately.
    func enqueue(_ track: MusicTrack) {
        guard currentTrack != nil else {
            play(track)
            return
        }
        queue.append(track)
    }

    /// Reorders a queue entry while keeping the currently playing track selected.
    func moveQueueItem(from source: Int, to destination: Int) {
        guard queue.indices.contains(source), queue.indices.contains(destination),
              source != destination else { return }

        var updatedQueue = queue
        let movedTrack = updatedQueue.remove(at: source)
        updatedQueue.insert(movedTrack, at: destination)
        queue = updatedQueue

        guard let currentIndex = currentQueueIndex else { return }
        if currentIndex == source {
            currentQueueIndex = destination
        } else if source < currentIndex && destination >= currentIndex {
            currentQueueIndex = currentIndex - 1
        } else if source > currentIndex && destination <= currentIndex {
            currentQueueIndex = currentIndex + 1
        }
    }

    func removeQueueItem(at index: Int) {
        guard queue.indices.contains(index) else { return }

        let removedCurrentItem = index == currentQueueIndex
        queue.remove(at: index)

        guard !queue.isEmpty else {
            playQueue([])
            return
        }

        guard let currentQueueIndex else { return }

        if index < currentQueueIndex {
            self.currentQueueIndex = currentQueueIndex - 1
        } else if removedCurrentItem {
            let nextIndex = min(index, queue.count - 1)
            self.currentQueueIndex = nextIndex
            startTrack(queue[nextIndex])
        }
    }

    func toggleShuffle() {
        isShuffleEnabled.toggle()
    }

    func toggleRepeat() {
        isRepeatEnabled.toggle()
    }

    func togglePlayback() {
        if isResolving || isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func pause() {
        // A headset or lock-screen pause must also stop a stream that is still resolving.
        if isResolving {
            resolveTask?.cancel()
            resolveTask = nil
            isResolving = false
        }
        player?.pause()
        isPlaying = false
        isBuffering = false
        updateNowPlaying()
    }

    func resume() {
        guard let player else {
            // Re-resolve the current track when playback was paused before AVPlayer existed.
            if let track = currentTrack, !isResolving {
                startTrack(track)
            }
            return
        }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            player.play()
            isPlaying = true
            errorMessage = nil
            updateNowPlaying()
        } catch {
            errorMessage = "Tidak dapat melanjutkan audio: \(error.localizedDescription)"
        }
    }

    func playNext() {
        guard let currentQueueIndex else { return }

        let nextIndex: Int?
        if isShuffleEnabled, queue.count > 1 {
            let candidates = queue.indices.filter { $0 != currentQueueIndex }
            nextIndex = candidates.randomElement()
        } else {
            let candidate = currentQueueIndex + 1
            nextIndex = queue.indices.contains(candidate) ? candidate : nil
        }

        guard let nextIndex else {
            seek(to: 0)
            pause()
            return
        }

        self.currentQueueIndex = nextIndex
        startTrack(queue[nextIndex])
    }

    func playPrevious() {
        if position > 3 {
            seek(to: 0)
            return
        }

        guard let currentQueueIndex else { return }
        let previousIndex = max(0, currentQueueIndex - 1)
        self.currentQueueIndex = previousIndex
        startTrack(queue[previousIndex])
    }

    func seek(to seconds: Double) {
        guard seconds.isFinite else { return }
        let upperBound = duration > 0 ? duration : seconds
        let safePosition = max(0, min(seconds, upperBound))
        player?.seek(to: CMTime(seconds: safePosition, preferredTimescale: 600))
        position = safePosition
        updateNowPlaying()
    }

    private func handleTrackEnded() {
        guard isRepeatEnabled, let player else {
            playNext()
            return
        }

        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            guard finished else { return }
            Task { @MainActor in
                self?.resume()
            }
        }
    }

    private func startTrack(_ track: MusicTrack) {
        resolveTask?.cancel()
        resolveTask = nil
        isResolving = false
        player?.pause()
        detachPlaybackObservers()
        player = nil
        isPlaying = false

        currentTrack = track
        isBuffering = false
        position = 0
        duration = 0
        errorMessage = nil

        if loadedArtworkURL != track.artworkURL {
            artworkTask?.cancel()
            artworkTask = nil
            loadedArtworkURL = nil
            loadedArtwork = nil
        }

        // Direct online streams must use TLS; the KMP resolver also enforces HTTPS.
        if let url = track.streamURL, url.scheme?.lowercased() == "https" {
            startPlayer(track: track, url: url, headers: [:])
            return
        }

        guard let videoID = track.youtubeVideoID else {
            errorMessage = "Lagu ini belum memiliki ID video untuk mengambil stream audio."
            updateNowPlaying()
            return
        }

        isResolving = true
        updateNowPlaying()
        resolveTask = Task { [weak self] in
            guard let self else { return }
            do {
                guard let resolved = try await self.streamResolver.resolve(
                    videoId: videoID,
                    language: "id",
                    region: "ID",
                    quality: "high"
                ) else {
                    throw NSError(
                        domain: "MusikKuAudioResolver",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "Penyedia tidak memberikan stream audio untuk lagu ini."]
                    )
                }

                guard !Task.isCancelled, self.currentTrack?.id == track.id else { return }
                guard let url = URL(string: resolved.url),
                      url.scheme?.lowercased() == "https" else {
                    throw NSError(
                        domain: "MusikKuAudioResolver",
                        code: 422,
                        userInfo: [NSLocalizedDescriptionKey: "Alamat stream audio tidak valid."]
                    )
                }

                let headerData = Data(resolved.headersJson.utf8)
                let headers = (try? JSONSerialization.jsonObject(with: headerData)) as? [String: String] ?? [:]
                self.resolveTask = nil
                self.isResolving = false
                self.startPlayer(track: track, url: url, headers: headers)
            } catch {
                guard !Task.isCancelled, self.currentTrack?.id == track.id else { return }
                self.resolveTask = nil
                self.isResolving = false
                self.isPlaying = false
                self.errorMessage = "Gagal mengambil stream audio: \(error.localizedDescription)"
                self.updateNowPlaying()
            }
        }
    }

    private func startPlayer(track: MusicTrack, url: URL, headers: [String: String]) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            isPlaying = false
            errorMessage = "Tidak dapat mengaktifkan audio iOS: \(error.localizedDescription)"
            updateNowPlaying()
            return
        }

        errorMessage = nil
        let assetOptions: [String: Any]? = headers.isEmpty
            ? nil
            : ["AVURLAssetHTTPHeaderFieldsKey": headers]
        let asset = AVURLAsset(url: url, options: assetOptions)
        let item = AVPlayerItem(asset: asset)
        let nextPlayer = AVPlayer(playerItem: item)
        player = nextPlayer
        attachTimeObserver(to: nextPlayer)

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleTrackEnded()
            }
        }

        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] observedItem, _ in
            guard observedItem.status == .failed else { return }
            let message = observedItem.error?.localizedDescription ?? "Sumber audio tidak dapat diputar."
            Task { @MainActor in
                guard let self,
                      self.player?.currentItem === observedItem,
                      self.currentTrack?.id == track.id else {
                    return
                }
                self.errorMessage = "Pemutaran gagal: \(message)"
                self.isPlaying = false
                self.isBuffering = false
                self.player?.pause()
                self.updateNowPlaying()
            }
        }

        // Distinguish an active playback request from actual network buffering.
        // Keep the pause intent visible while AVPlayer waits for bytes to arrive.
        timeControlObservation = nextPlayer.observe(\.timeControlStatus, options: [.new]) { [weak self, weak nextPlayer] observedPlayer, _ in
            guard let nextPlayer else { return }
            Task { @MainActor in
                guard let self, self.player === nextPlayer else { return }
                switch nextPlayer.timeControlStatus {
                case .playing:
                    self.isPlaying = true
                    self.isBuffering = false
                case .waitingToPlayAtSpecifiedRate:
                    self.isBuffering = true
                case .paused:
                    self.isPlaying = false
                    self.isBuffering = false
                @unknown default:
                    self.isBuffering = false
                }
                self.updateNowPlaying()
            }
        }

        nextPlayer.play()
        playbackStartID = UUID()
        isPlaying = true
        updateNowPlaying()
    }

    private func attachTimeObserver(to newPlayer: AVPlayer) {
        observedPlayer = newPlayer
        timeObserver = newPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self, weak newPlayer] time in
            guard let self, let newPlayer else { return }
            Task { @MainActor in
                let seconds = time.seconds
                if seconds.isFinite {
                    self.position = max(0, seconds)
                }

                if let item = newPlayer.currentItem {
                    let total = item.duration.seconds
                    self.duration = total.isFinite ? max(0, total) : 0
                }
                self.updateNowPlaying()
            }
        }
    }

    private func detachPlaybackObservers() {
        if let timeObserver, let observedPlayer {
            observedPlayer.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        observedPlayer = nil

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil

        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        timeControlObservation?.invalidate()
        timeControlObservation = nil
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true
        center.skipForwardCommand.isEnabled = true
        center.skipBackwardCommand.isEnabled = true
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.preferredIntervals = [15]
        center.changePlaybackPositionCommand.isEnabled = true

        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                self?.seek(to: event.positionTime)
            }
            return .success
        }

        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayback() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.playNext() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.playPrevious() }
            return .success
        }
        center.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skip(by: 15) }
            return .success
        }
        center.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skip(by: -15) }
            return .success
        }
    }

    private func configureAudioSessionNotifications() {
        let token = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let rawType = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
                return
            }

            let shouldResume: Bool
            if let rawOptions = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                shouldResume = AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume)
            } else {
                shouldResume = false
            }

            Task { @MainActor in
                switch type {
                case .began:
                    self?.shouldResumeAfterInterruption = self?.isPlaying ?? false
                    self?.pause()
                case .ended:
                    if shouldResume, self?.shouldResumeAfterInterruption == true {
                        self?.shouldResumeAfterInterruption = false
                        self?.resume()
                    }
                @unknown default:
                    break
                }
            }
        }
        notificationObservers.append(token)

        let routeToken = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason),
                  reason == .oldDeviceUnavailable else {
                return
            }

            Task { @MainActor in
                self?.pause()
            }
        }
        notificationObservers.append(routeToken)
    }

    private func skip(by interval: Double) {
        seek(to: position + interval)
    }

    private func updateNowPlaying() {
        guard let currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentTrack.title,
            MPMediaItemPropertyArtist: currentTrack.artist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        if let album = currentTrack.album {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        if let artwork = loadedArtwork,
           loadedArtworkURL == currentTrack.artworkURL {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
        } else if let artworkURL = currentTrack.artworkURL,
                  loadedArtworkURL != artworkURL,
                  artworkTask == nil {
            artworkTask = Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: artworkURL)
                    guard !Task.isCancelled,
                          self.currentTrack?.artworkURL == artworkURL,
                          let image = UIImage(data: data) else {
                        self.artworkTask = nil
                        return
                    }

                    self.loadedArtworkURL = artworkURL
                    self.loadedArtwork = image
                    self.artworkTask = nil
                    self.updateNowPlaying()
                } catch {
                    self.artworkTask = nil
                }
            }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
