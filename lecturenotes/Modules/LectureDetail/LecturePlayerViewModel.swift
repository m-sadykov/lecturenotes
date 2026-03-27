import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class LecturePlayerViewModel {
    static let availablePlaybackRates: [Float] = [0.5, 0.75, 1, 1.25, 1.5, 2]

    var isPlaying = false
    var playbackRate: Float = 1
    var currentTime: Duration = .zero
    var totalDuration: Duration = .zero

    @ObservationIgnored private let player: AVPlayer?
    @ObservationIgnored private let audioSession = AVAudioSession.sharedInstance()
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var durationTask: Task<Void, Never>?

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
        let totalSeconds = max(totalDuration.timeInterval, 1)
        let currentSeconds = max(currentTime.timeInterval, 0)
        return min(1, currentSeconds / totalSeconds)
    }

    func togglePlayback() {
        guard let player else { return }

        if isPlaying {
            player.pause()
            isPlaying = false
            deactivatePlaybackSessionIfNeeded()
            return
        }

        activatePlaybackSessionIfNeeded()

        if totalDuration.timeInterval > 0, currentTime.timeInterval >= totalDuration.timeInterval {
            let startTime = CMTime(seconds: 0, preferredTimescale: 600)
            player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
            currentTime = .zero
        }

        player.playImmediately(atRate: playbackRate)
        isPlaying = true
    }

    func seek(to progress: Double) {
        guard let player else { return }

        let totalSeconds = max(totalDuration.timeInterval, 0)
        let seconds = totalSeconds * min(1, max(0, progress))
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func seek(by offset: Duration) {
        guard let player else { return }

        let targetSeconds = max(
            Double.zero,
            min(
                totalDuration.timeInterval,
                currentTime.timeInterval + offset.timeInterval
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

    func cyclePlaybackRate() {
        guard let currentIndex = Self.availablePlaybackRates.firstIndex(of: playbackRate) else {
            setPlaybackRate(Self.availablePlaybackRates[0])
            return
        }

        let nextIndex = Self.availablePlaybackRates.index(after: currentIndex)
        let nextRate = nextIndex < Self.availablePlaybackRates.endIndex
            ? Self.availablePlaybackRates[nextIndex]
            : Self.availablePlaybackRates[0]
        setPlaybackRate(nextRate)
    }

    func pausePlayback() {
        guard let player else { return }
        player.pause()
        isPlaying = false
        deactivatePlaybackSessionIfNeeded()
    }

    func cleanup() {
        durationTask?.cancel()
        durationTask = nil
        guard let timeObserver, let player else { return }
        player.removeTimeObserver(timeObserver)
        self.timeObserver = nil
        player.pause()
        isPlaying = false
        deactivatePlaybackSessionIfNeeded()
    }

    private func configurePlayer() {
        guard let player else { return }

        durationTask = Task { [weak self] in
            guard
                let self,
                let currentItem = player.currentItem
            else {
                return
            }

            do {
                let itemDuration = try await currentItem.asset.load(.duration)
                let seconds = itemDuration.seconds
                guard seconds.isFinite, seconds > 0 else {
                    return
                }
                totalDuration = .seconds(seconds)
            } catch {
                // Keep the fallback duration if asset loading fails.
            }
        }

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else {
                return
            }

            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                currentTime = .seconds(time.seconds)

                let totalSeconds = totalDuration.timeInterval
                if totalSeconds > 0, time.seconds >= totalSeconds {
                    isPlaying = false
                    currentTime = .zero
                    player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
                }
            }
        }
    }

    private func activatePlaybackSessionIfNeeded() {
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            // Playback can still be attempted even if session activation fails.
        }
    }

    private func deactivatePlaybackSessionIfNeeded() {
        try? audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        TimeInterval(components.seconds) + (TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000)
    }
}
