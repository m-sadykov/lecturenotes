import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class LecturePlayerViewModel {
    var isPlaying = false
    var playbackRate: Float = 1
    var currentTime: Duration = .zero
    var totalDuration: Duration = .zero

    @ObservationIgnored private let player: AVPlayer?
    @ObservationIgnored private var timeObserver: Any?

    init(audioURL: URL?, fallbackDuration: Duration) {
        if let audioURL {
            self.player = AVPlayer(url: audioURL)
        } else {
            self.player = nil
        }

        self.totalDuration = fallbackDuration
        configurePlayer()
    }

    var canPlay: Bool {
        player != nil
    }

    var progress: Double {
        let totalSeconds = max(Double(totalDuration.components.seconds), 1)
        let currentSeconds = max(Double(currentTime.components.seconds), 0)
        return min(1, currentSeconds / totalSeconds)
    }

    func togglePlayback() {
        guard let player else { return }

        if isPlaying {
            player.pause()
            isPlaying = false
            return
        }

        player.playImmediately(atRate: playbackRate)
        isPlaying = true
    }

    func seek(to progress: Double) {
        guard let player else { return }

        let totalSeconds = max(Double(totalDuration.components.seconds), 0)
        let seconds = totalSeconds * min(1, max(0, progress))
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func seek(by offset: Duration) {
        guard let player else { return }

        let targetSeconds = max(
            Double.zero,
            min(
                Double(totalDuration.components.seconds),
                Double(currentTime.components.seconds + offset.components.seconds)
            )
        )
        let time = CMTime(seconds: targetSeconds, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate

        guard let player, isPlaying else { return }
        player.rate = rate
    }

    func pausePlayback() {
        guard let player else { return }
        player.pause()
        isPlaying = false
    }

    func cleanup() {
        guard let timeObserver, let player else { return }
        player.removeTimeObserver(timeObserver)
        self.timeObserver = nil
        player.pause()
        isPlaying = false
    }

    private func configurePlayer() {
        guard let player else { return }

        if let itemDuration = player.currentItem?.asset.duration.seconds, itemDuration.isFinite, itemDuration > 0 {
            totalDuration = .seconds(itemDuration)
        }

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            currentTime = .seconds(time.seconds)

            if
                let itemDuration = player.currentItem?.duration.seconds,
                itemDuration.isFinite,
                itemDuration > 0
            {
                totalDuration = .seconds(itemDuration)
            }

            if
                let currentItem = player.currentItem,
                currentItem.status == .readyToPlay,
                currentItem.duration.isNumeric,
                time.seconds >= currentItem.duration.seconds
            {
                isPlaying = false
            }
        }
    }
}
