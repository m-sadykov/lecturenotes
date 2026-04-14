import AVFoundation
import MediaPlayer
import UIKit

@MainActor
final class LectureNowPlayingManager: NSObject {
    private let nowPlayingCenter = MPNowPlayingInfoCenter.default()
    private let remoteCommandCenter = MPRemoteCommandCenter.shared()

    private var onTogglePlayback: (() -> Void)?
    private var onPlay: (() -> Void)?
    private var onPause: (() -> Void)?
    private var onSkipForward: (() -> Void)?
    private var onSkipBackward: (() -> Void)?
    private var onSeek: ((TimeInterval) -> Void)?

    override init() {
        super.init()
        configureRemoteCommands()
    }

    deinit {
        remoteCommandCenter.playCommand.removeTarget(self)
        remoteCommandCenter.pauseCommand.removeTarget(self)
        remoteCommandCenter.togglePlayPauseCommand.removeTarget(self)
        remoteCommandCenter.skipForwardCommand.removeTarget(self)
        remoteCommandCenter.skipBackwardCommand.removeTarget(self)
        remoteCommandCenter.changePlaybackPositionCommand.removeTarget(self)
    }

    func configureHandlers(
        onTogglePlayback: @escaping () -> Void,
        onPlay: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onSkipForward: @escaping () -> Void,
        onSkipBackward: @escaping () -> Void,
        onSeek: @escaping (TimeInterval) -> Void
    ) {
        self.onTogglePlayback = onTogglePlayback
        self.onPlay = onPlay
        self.onPause = onPause
        self.onSkipForward = onSkipForward
        self.onSkipBackward = onSkipBackward
        self.onSeek = onSeek
    }

    func update(
        title: String,
        currentTime: Duration,
        totalDuration: Duration,
        playbackRate: Float,
        isPlaying: Bool
    ) {
        var nowPlayingInfo = nowPlayingCenter.nowPlayingInfo ?? [:]
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = String(localized: "LectraAI")
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = totalDuration.timeInterval
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime.timeInterval
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackRate : 0
        nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = playbackRate

        if let artwork = makeArtwork(), nowPlayingInfo[MPMediaItemPropertyArtwork] == nil {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }

        nowPlayingCenter.nowPlayingInfo = nowPlayingInfo
        nowPlayingCenter.playbackState = isPlaying ? .playing : .paused
    }

    func clear() {
        nowPlayingCenter.nowPlayingInfo = nil
        nowPlayingCenter.playbackState = .stopped
    }

    private func configureRemoteCommands() {
        remoteCommandCenter.playCommand.isEnabled = true
        remoteCommandCenter.pauseCommand.isEnabled = true
        remoteCommandCenter.togglePlayPauseCommand.isEnabled = true
        remoteCommandCenter.skipForwardCommand.isEnabled = true
        remoteCommandCenter.skipBackwardCommand.isEnabled = true
        remoteCommandCenter.changePlaybackPositionCommand.isEnabled = true
        remoteCommandCenter.nextTrackCommand.isEnabled = false
        remoteCommandCenter.previousTrackCommand.isEnabled = false

        remoteCommandCenter.skipForwardCommand.preferredIntervals = [15]
        remoteCommandCenter.skipBackwardCommand.preferredIntervals = [15]

        remoteCommandCenter.playCommand.addTarget(self, action: #selector(handlePlayCommand))
        remoteCommandCenter.pauseCommand.addTarget(self, action: #selector(handlePauseCommand))
        remoteCommandCenter.togglePlayPauseCommand.addTarget(self, action: #selector(handleTogglePlayPauseCommand))
        remoteCommandCenter.skipForwardCommand.addTarget(self, action: #selector(handleSkipForwardCommand))
        remoteCommandCenter.skipBackwardCommand.addTarget(self, action: #selector(handleSkipBackwardCommand))
        remoteCommandCenter.changePlaybackPositionCommand.addTarget(self, action: #selector(handleChangePlaybackPositionCommand(_:)))
    }

    private func makeArtwork() -> MPMediaItemArtwork? {
        guard let image = UIImage(named: "AppIcon") else {
            return nil
        }

        return MPMediaItemArtwork(boundsSize: image.size) { _ in
            image
        }
    }

    @objc
    private func handlePlayCommand() -> MPRemoteCommandHandlerStatus {
        guard let onPlay else {
            return .commandFailed
        }

        onPlay()
        return .success
    }

    @objc
    private func handlePauseCommand() -> MPRemoteCommandHandlerStatus {
        guard let onPause else {
            return .commandFailed
        }

        onPause()
        return .success
    }

    @objc
    private func handleTogglePlayPauseCommand() -> MPRemoteCommandHandlerStatus {
        guard let onTogglePlayback else {
            return .commandFailed
        }

        onTogglePlayback()
        return .success
    }

    @objc
    private func handleSkipForwardCommand() -> MPRemoteCommandHandlerStatus {
        guard let onSkipForward else {
            return .commandFailed
        }

        onSkipForward()
        return .success
    }

    @objc
    private func handleSkipBackwardCommand() -> MPRemoteCommandHandlerStatus {
        guard let onSkipBackward else {
            return .commandFailed
        }

        onSkipBackward()
        return .success
    }

    @objc
    private func handleChangePlaybackPositionCommand(_ event: MPChangePlaybackPositionCommandEvent) -> MPRemoteCommandHandlerStatus {
        guard let onSeek else {
            return .commandFailed
        }

        onSeek(event.positionTime)
        return .success
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        TimeInterval(components.seconds) + (TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000)
    }
}
