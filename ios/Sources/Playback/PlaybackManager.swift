import AVFoundation
import Combine
import MediaPlayer

@MainActor
final class PlaybackManager: ObservableObject {
    @Published private(set) var currentTrack: MusicTrack?
    @Published private(set) var isPlaying = false
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published var errorMessage: String?

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var observedPlayer: AVPlayer?

    init() {
        configureRemoteCommands()
    }

    /// Plays a remote stream URL supplied by a provider that is authorized for this app.
    func play(_ track: MusicTrack) {
        guard let url = track.streamURL,
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            errorMessage = "Track ini belum memiliki URL streaming yang valid dari penyedia musik."
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            errorMessage = "Tidak dapat mengaktifkan audio iOS: \(error.localizedDescription)"
            return
        }

        detachTimeObserver()
        currentTrack = track
        position = 0
        duration = 0
        errorMessage = nil

        let nextPlayer = AVPlayer(playerItem: AVPlayerItem(url: url))
        player = nextPlayer
        attachTimeObserver(to: nextPlayer)
        nextPlayer.play()
        isPlaying = true
        updateNowPlaying()
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

    func seek(to seconds: Double) {
        guard seconds.isFinite else { return }
        let safePosition = max(0, min(seconds, duration > 0 ? duration : seconds))
        player?.seek(to: CMTime(seconds: safePosition, preferredTimescale: 600))
        position = safePosition
        updateNowPlaying()
    }

    private func skip(by interval: Double) {
        seek(to: position + interval)
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

    private func detachTimeObserver() {
        if let timeObserver, let observedPlayer {
            observedPlayer.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        observedPlayer = nil
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
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
        center.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skip(by: 15) }
            return .success
        }
        center.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skip(by: -15) }
            return .success
        }
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
