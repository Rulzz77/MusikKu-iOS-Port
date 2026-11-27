import AVFoundation
import Combine
import MediaPlayer

@MainActor
final class PlaybackManager: ObservableObject {
    @Published private(set) var currentTrack: MusicTrack?
    @Published private(set) var isPlaying = false
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var queue: [MusicTrack] = []
    @Published var errorMessage: String?

    private var currentQueueIndex: Int?
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var observedPlayer: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var notificationObservers: [NSObjectProtocol] = []
    private var itemStatusObservation: NSKeyValueObservation?
    private var shouldResumeAfterInterruption = false

    init() {
        configureRemoteCommands()
        configureAudioSessionNotifications()
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
            pause()
            currentTrack = nil
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

    func togglePlayback() {
        isPlaying ? pause() : resume()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlaying()
    }

    func resume() {
        guard let player else { return }
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
        let nextIndex = currentQueueIndex + 1
        guard queue.indices.contains(nextIndex) else {
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

    private func startTrack(_ track: MusicTrack) {
        player?.pause()
        detachPlaybackObservers()

        currentTrack = track
        position = 0
        duration = 0

        guard let url = track.streamURL,
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            isPlaying = false
            errorMessage = "Track ini belum memiliki URL streaming yang valid dari penyedia musik."
            updateNowPlaying()
            return
        }

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
        let item = AVPlayerItem(url: url)
        let nextPlayer = AVPlayer(playerItem: item)
        player = nextPlayer
        attachTimeObserver(to: nextPlayer)

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.playNext()
            }
        }

        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] observedItem, _ in
            guard observedItem.status == .failed else { return }
            let message = observedItem.error?.localizedDescription ?? "Sumber audio tidak dapat diputar."
            Task { @MainActor in
                self?.errorMessage = "Pemutaran gagal: \(message)"
                self?.isPlaying = false
                self?.updateNowPlaying()
            }
        }

        nextPlayer.play()
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
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
