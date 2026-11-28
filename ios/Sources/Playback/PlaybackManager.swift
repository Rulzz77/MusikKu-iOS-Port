import AVFoundation
import Combine
import MediaPlayer
import UIKit
import MusikKuResolverKit

enum PlaybackRepeatMode: String, CaseIterable, Identifiable, Hashable {
    case off
    case all
    case one

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Tidak diulang"
        case .all: return "Ulangi antrean"
        case .one: return "Ulangi satu lagu"
        }
    }
}

@MainActor
final class PlaybackManager: ObservableObject {
    @Published private(set) var currentTrack: MusicTrack?
    @Published private(set) var playbackStartID = UUID()
    @Published private(set) var playbackHeartbeatID = UUID()
    @Published private(set) var isPlaying = false
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var queue: [MusicTrack] = []
    @Published private(set) var isShuffleEnabled = false
    @Published private(set) var repeatMode: PlaybackRepeatMode = .off
    @Published private(set) var playbackSpeed: Double = 1.0
    @Published private(set) var sleepTimerEndDate: Date?
    @Published private(set) var sleepTimerAfterTrack = false
    @Published private(set) var sleepTimerFadeOutEnabled = true
    @Published private(set) var isResolving = false
    @Published private(set) var isBuffering = false
    @Published private(set) var playbackStatusMessage: String?
    /// Safe metadata only: never contains signed stream URLs, request headers, or PO tokens.
    @Published private(set) var resolvedStreamInfo: String?
    @Published var errorMessage: String?

    private var currentQueueIndex: Int?
    private var pendingPlaybackStartTrackID: String?
    private var sleepTimerTask: Task<Void, Never>?
    private var sleepTimerOriginalVolume: Float = 1.0
    private let sleepTimerFadeOutKey = "musikku.player.sleep-timer-fade-out.v1"
    private let playbackSpeedKey = "musikku.player.playback-speed.v1"
    private let repeatModeKey = "musikku.player.repeat-mode.v1"
    var currentQueueTrackIndex: Int? { currentQueueIndex }
    var isRepeatEnabled: Bool { repeatMode != .off }

    static let availablePlaybackSpeeds: [Double] = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

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
        sleepTimerFadeOutEnabled = UserDefaults.standard.object(forKey: sleepTimerFadeOutKey) as? Bool ?? true
        let savedSpeed = UserDefaults.standard.double(forKey: playbackSpeedKey)
        if Self.availablePlaybackSpeeds.contains(where: { abs($0 - savedSpeed) < 0.001 }) {
            playbackSpeed = savedSpeed
        }
        if let savedRepeat = UserDefaults.standard.string(forKey: repeatModeKey),
           let mode = PlaybackRepeatMode(rawValue: savedRepeat) {
            repeatMode = mode
        }
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
            playbackStatusMessage = nil
            resolvedStreamInfo = nil
            errorMessage = nil
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
        let nextIndex = (PlaybackRepeatMode.allCases.firstIndex(of: repeatMode) ?? -1) + 1
        setRepeatMode(PlaybackRepeatMode.allCases[nextIndex % PlaybackRepeatMode.allCases.count])
    }

    func setRepeatMode(_ mode: PlaybackRepeatMode) {
        repeatMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: repeatModeKey)
    }

    func setPlaybackSpeed(_ speed: Double) {
        guard let supported = Self.availablePlaybackSpeeds.first(where: { abs($0 - speed) < 0.001 }) else {
            return
        }
        playbackSpeed = supported
        UserDefaults.standard.set(supported, forKey: playbackSpeedKey)
        if let player, isPlaying {
            player.rate = Float(supported)
        }
        updateNowPlaying()
    }

    /// Android-aligned sleep timer: 5-minute steps, from 5 minutes to 12 hours.
    func setSleepTimer(minutes: Int?) {
        cancelSleepTimer()
        guard let minutes, (5...720).contains(minutes), minutes.isMultiple(of: 5) else { return }

        sleepTimerAfterTrack = false
        sleepTimerOriginalVolume = player?.volume ?? 1.0
        let endDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        sleepTimerEndDate = endDate

        sleepTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let remaining = endDate.timeIntervalSinceNow
                guard remaining > 0 else {
                    self.finishSleepTimer()
                    return
                }

                if remaining > 30 {
                    let untilFade = remaining - 30
                    let sleepNanoseconds = UInt64(max(0.1, untilFade) * 1_000_000_000)
                    do {
                        try await Task.sleep(nanoseconds: sleepNanoseconds)
                    } catch {
                        return
                    }
                    continue
                }

                self.applySleepTimerFade(remainingSeconds: remaining)
                do {
                    try await Task.sleep(nanoseconds: 500_000_000)
                } catch {
                    return
                }
            }
        }
    }

    /// Stops at the end of the currently playing track instead of using a deadline.
    func setSleepTimerAfterTrack() {
        guard currentTrack != nil else { return }
        cancelSleepTimer()
        sleepTimerAfterTrack = true
    }

    func setSleepTimerFadeOutEnabled(_ enabled: Bool) {
        sleepTimerFadeOutEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: sleepTimerFadeOutKey)
        if !enabled {
            restoreSleepTimerVolume()
        }
    }

    func cancelSleepTimer() {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        sleepTimerEndDate = nil
        sleepTimerAfterTrack = false
        restoreSleepTimerVolume()
    }

    private func applySleepTimerFade(remainingSeconds: TimeInterval) {
        guard let player else { return }
        guard sleepTimerFadeOutEnabled else {
            player.volume = sleepTimerOriginalVolume
            return
        }
        let fadeDuration: TimeInterval = 30
        let multiplier: Float
        if remainingSeconds >= fadeDuration {
            multiplier = 1
        } else {
            multiplier = Float(max(0, min(1, remainingSeconds / fadeDuration)))
        }
        player.volume = sleepTimerOriginalVolume * multiplier
    }

    private func restoreSleepTimerVolume() {
        player?.volume = sleepTimerOriginalVolume
    }

    private func finishSleepTimer() {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        sleepTimerEndDate = nil
        sleepTimerAfterTrack = false
        restoreSleepTimerVolume()
        pause()
    }

    func togglePlayback() {
        if isResolving || isPlaying || isBuffering {
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
        if currentTrack != nil && errorMessage == nil {
            playbackStatusMessage = "Dijeda"
        }
        updateNowPlaying()
    }

    func resume() {
        // AVPlayer keeps a failed item attached; calling play() again cannot recover it.
        // Recreate the item and resolve a fresh stream when the user taps Play after an error.
        if player?.currentItem?.status == .failed, let track = currentTrack {
            playbackStatusMessage = "Mencoba memutar ulang…"
            startTrack(track)
            return
        }

        guard let player else {
            // Re-resolve the current track when playback was paused before AVPlayer existed.
            if let track = currentTrack, !isResolving {
                startTrack(track)
            }
            return
        }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            player.playImmediately(atRate: Float(playbackSpeed))
            isPlaying = true
            errorMessage = nil
            updateNowPlaying()
        } catch {
            errorMessage = "Tidak dapat melanjutkan audio: \(MusikKuErrorMessage.indonesianMessage(for: error, fallback: "Perangkat menolak permintaan audio."))"
            playbackStatusMessage = errorMessage
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
            if queue.indices.contains(candidate) {
                nextIndex = candidate
            } else {
                nextIndex = repeatMode == .all ? queue.indices.first : nil
            }
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
        if sleepTimerAfterTrack {
            finishSleepTimer()
            return
        }

        guard repeatMode == .one, let player else {
            playNext()
            return
        }

        pendingPlaybackStartTrackID = currentTrack?.id
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
        pendingPlaybackStartTrackID = track.id
        isBuffering = false
        playbackStatusMessage = "Menyiapkan pemutaran…"
        resolvedStreamInfo = nil
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
            resolvedStreamInfo = "Stream HTTPS langsung"
            startPlayer(track: track, url: url, headers: [:])
            return
        }

        guard let videoID = track.youtubeVideoID else {
            errorMessage = "Lagu ini belum memiliki ID video untuk mengambil stream audio."
            playbackStatusMessage = errorMessage
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
                guard let headers = (try? JSONSerialization.jsonObject(with: headerData)) as? [String: String] else {
                    throw NSError(
                        domain: "MusikKuAudioResolver",
                        code: 423,
                        userInfo: [NSLocalizedDescriptionKey: "Metadata header stream dari penyedia tidak valid."]
                    )
                }
                self.resolvedStreamInfo = [
                    resolved.clientName,
                    resolved.mimeType ?? "format tidak diketahui"
                ].joined(separator: " • ")
                self.playbackStatusMessage = "Stream ditemukan, memulai audio…"
                self.resolveTask = nil
                self.isResolving = false
                self.startPlayer(
                    track: track,
                    url: url,
                    headers: headers,
                    resolvedProfileID: resolved.profileId
                )
            } catch {
                guard !Task.isCancelled, self.currentTrack?.id == track.id else { return }
                self.pendingPlaybackStartTrackID = nil
                self.resolveTask = nil
                self.isResolving = false
                self.isPlaying = false
                let technicalError = error as NSError
                let technicalCode = "\(technicalError.domain.prefix(48)) (\(technicalError.code))"
                self.errorMessage = "Gagal mengambil stream audio: \(MusikKuErrorMessage.indonesianMessage(for: error, fallback: "Penyedia musik tidak dapat menyiapkan audio saat ini."))\nDetail: \(technicalCode)"
                self.playbackStatusMessage = self.errorMessage
                self.updateNowPlaying()
            }
        }
    }

    private func startPlayer(
        track: MusicTrack,
        url: URL,
        headers: [String: String],
        resolvedProfileID: String? = nil
    ) {
        playbackStatusMessage = "Menghubungkan ke pemutar audio…"
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            pendingPlaybackStartTrackID = nil
            isPlaying = false
            errorMessage = "Tidak dapat mengaktifkan audio iOS: \(MusikKuErrorMessage.indonesianMessage(for: error, fallback: "Periksa pengaturan audio perangkat lalu coba lagi."))"
            playbackStatusMessage = errorMessage
            updateNowPlaying()
            return
        }

        errorMessage = nil
        let assetOptions: [String: Any]? = headers.isEmpty
            ? nil
            : ["AVURLAssetHTTPHeaderFieldsKey": headers]
        let asset = AVURLAsset(url: url, options: assetOptions)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 6
        let nextPlayer = AVPlayer(playerItem: item)
        nextPlayer.automaticallyWaitsToMinimizeStalling = true
        nextPlayer.volume = sleepTimerOriginalVolume
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
            let itemError = observedItem.error
            let message = itemError.map { MusikKuErrorMessage.indonesianMessage(for: $0, fallback: "Sumber audio tidak dapat diputar.") } ?? "Sumber audio tidak dapat diputar."
            let technicalCode = itemError.map {
                let nsError = $0 as NSError
                return "\(nsError.domain.prefix(48)) (\(nsError.code))"
            }
            Task { @MainActor in
                guard let self else { return }
                if let failedProfileID = resolvedProfileID,
                   let videoID = track.youtubeVideoID {
                    try? await self.streamResolver.markStreamProfileFailed(
                        videoId: videoID,
                        profileId: failedProfileID
                    )
                }
                guard self.player?.currentItem === observedItem,
                      self.currentTrack?.id == track.id else { return }
                let detail = technicalCode.map { "\nDetail: \($0)" } ?? ""
                self.errorMessage = "Pemutaran gagal: \(message)\(detail)"
                self.playbackStatusMessage = self.errorMessage
                self.isPlaying = false
                self.isBuffering = false
                self.player?.pause()
                self.updateNowPlaying()
            }
        }

        // Distinguish an active playback request from actual network buffering.
        // Keep the pause intent visible while AVPlayer waits for bytes to arrive.
        timeControlObservation = nextPlayer.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self, weak nextPlayer] observedPlayer, _ in
            guard let nextPlayer else { return }
            Task { @MainActor in
                guard let self, self.player === nextPlayer else { return }
                switch nextPlayer.timeControlStatus {
                case .playing:
                    if self.pendingPlaybackStartTrackID == self.currentTrack?.id {
                        self.pendingPlaybackStartTrackID = nil
                        self.playbackStartID = UUID()
                    }
                    self.isPlaying = true
                    self.isBuffering = false
                    self.playbackStatusMessage = "Sedang diputar"
                case .waitingToPlayAtSpecifiedRate:
                    self.isBuffering = true
                    self.playbackStatusMessage = "Menunggu data audio…"
                case .paused:
                    self.isPlaying = false
                    self.isBuffering = false
                    if self.errorMessage == nil {
                        self.playbackStatusMessage = "Dijeda"
                    }
                @unknown default:
                    self.isBuffering = false
                }
                self.updateNowPlaying()
            }
        }

        nextPlayer.playImmediately(atRate: Float(playbackSpeed))
        isPlaying = false
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
                if newPlayer.timeControlStatus == .playing {
                    self.playbackHeartbeatID = UUID()
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
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? playbackSpeed : 0.0
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
