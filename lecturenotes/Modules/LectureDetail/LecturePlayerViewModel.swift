import AVFoundation
import FirebaseStorage
import Foundation
import Observation

@MainActor
@Observable
final class LecturePlayerViewModel {
    static let availablePlaybackRates: [Float] = [0.5, 0.75, 1, 1.25, 1.5, 2]

    var isPlaying = false
    var isPlaybackAvailable = false
    var playbackRate: Float = 1
    var currentTime: Duration = .zero
    var totalDuration: Duration = .zero

    @ObservationIgnored private var player: AVPlayer?
    @ObservationIgnored private let analyticsService: AppAnalyticsService?
    @ObservationIgnored private var analyticsContext: LectureAnalyticsContext?
    @ObservationIgnored private let audioSession = AVAudioSession.sharedInstance()
    @ObservationIgnored private let fileManager: FileManager
    @ObservationIgnored private let storage: Storage
    @ObservationIgnored private let nowPlayingManager: LectureNowPlayingManager
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var durationTask: Task<Void, Never>?
    @ObservationIgnored private var remoteURLTask: Task<Void, Never>?
    @ObservationIgnored private var configuredLocalAudioURL: URL?
    @ObservationIgnored private var configuredRemoteAudioPath: String?
    @ObservationIgnored private var lectureTitle: String

    init(
        lectureTitle: String,
        audioURL: URL?,
        remoteAudioPath: String?,
        fallbackDuration: Duration,
        analyticsService: AppAnalyticsService? = nil,
        analyticsContext: LectureAnalyticsContext? = nil,
        fileManager: FileManager = .default,
        storage: Storage = .storage(),
        nowPlayingManager: LectureNowPlayingManager? = nil
    ) {
        self.analyticsService = analyticsService
        self.lectureTitle = lectureTitle
        self.fileManager = fileManager
        self.storage = storage
        self.nowPlayingManager = nowPlayingManager ?? LectureNowPlayingManager()
        configureNowPlayingManager()
        updateAudio(
            lectureTitle: lectureTitle,
            localURL: audioURL,
            remoteAudioPath: remoteAudioPath,
            fallbackDuration: fallbackDuration,
            analyticsContext: analyticsContext
        )
    }

    var canPlay: Bool {
        isPlaybackAvailable
    }

    var progress: Double {
        let totalSeconds = max(totalDuration.timeInterval, 1)
        let currentSeconds = max(currentTime.timeInterval, 0)
        return min(1, currentSeconds / totalSeconds)
    }

    func updateAudio(
        lectureTitle: String,
        localURL: URL?,
        remoteAudioPath: String?,
        fallbackDuration: Duration,
        analyticsContext: LectureAnalyticsContext? = nil
    ) {
        totalDuration = fallbackDuration
        self.lectureTitle = lectureTitle
        self.analyticsContext = analyticsContext

        let needsReconfiguration =
            configuredLocalAudioURL != localURL ||
            configuredRemoteAudioPath != remoteAudioPath

        updateNowPlaying()

        guard needsReconfiguration else {
            return
        }

        configuredLocalAudioURL = localURL
        configuredRemoteAudioPath = remoteAudioPath
        configurePlaybackSource(localURL: localURL, remoteAudioPath: remoteAudioPath)
    }

    func togglePlayback() {
        guard canPlay, let player else { return }

        if isPlaying {
            player.pause()
            isPlaying = false
            deactivatePlaybackSessionIfNeeded()
            updateNowPlaying()
            if let analyticsContext {
                analyticsService?.track(
                    .audioPlayPaused(
                        context: analyticsContext,
                        positionSeconds: currentTime.timeInterval
                    )
                )
            }
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
        updateNowPlaying()
        if let analyticsContext {
            analyticsService?.track(.audioPlayStarted(context: analyticsContext))
        }
    }

    func seek(to progress: Double) {
        guard canPlay, let player else { return }

        let totalSeconds = max(totalDuration.timeInterval, 0)
        let seconds = totalSeconds * min(1, max(0, progress))
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = .seconds(seconds)
        updateNowPlaying()
    }

    func seek(by offset: Duration) {
        guard canPlay, let player else { return }

        let targetSeconds = max(
            Double.zero,
            min(
                totalDuration.timeInterval,
                currentTime.timeInterval + offset.timeInterval
            )
        )
        let time = CMTime(seconds: targetSeconds, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = .seconds(targetSeconds)
        updateNowPlaying()
    }

    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate

        guard canPlay, let player, isPlaying else { return }
        player.rate = rate
        updateNowPlaying()
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
        updateNowPlaying()
    }

    func cleanup() {
        tearDownPlayer()
        configuredLocalAudioURL = nil
        configuredRemoteAudioPath = nil
        isPlaybackAvailable = false
    }

    private func configurePlaybackSource(localURL: URL?, remoteAudioPath: String?) {
        remoteURLTask?.cancel()
        remoteURLTask = nil

        if isPlayableLocalFile(localURL) {
            replacePlayerIfNeeded(with: localURL)
            return
        }

        guard let remoteAudioPath, !remoteAudioPath.isEmpty else {
            replacePlayerIfNeeded(with: nil)
            return
        }

        replacePlayerIfNeeded(with: nil)
        remoteURLTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let remoteURL = try await storage.reference(withPath: remoteAudioPath).downloadURL()
                guard !Task.isCancelled else {
                    return
                }

                remoteURLTask = nil
                replacePlayerIfNeeded(with: remoteURL)
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                remoteURLTask = nil
                replacePlayerIfNeeded(with: nil)
            }
        }
    }

    private func replacePlayerIfNeeded(with audioURL: URL?) {
        tearDownPlayer()
        currentTime = .zero

        guard let audioURL else {
            isPlaybackAvailable = false
            return
        }

        let player = AVPlayer(url: audioURL)
        self.player = player
        isPlaybackAvailable = true
        configurePlayer(player)
    }

    private func tearDownPlayer() {
        remoteURLTask?.cancel()
        remoteURLTask = nil
        durationTask?.cancel()
        durationTask = nil

        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }

        timeObserver = nil
        player?.pause()
        player = nil
        isPlaybackAvailable = false
        isPlaying = false
        deactivatePlaybackSessionIfNeeded()
        nowPlayingManager.clear()
    }

    private func configurePlayer(_ player: AVPlayer) {
        durationTask?.cancel()

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
                updateNowPlaying()
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
                updateNowPlaying()

                let totalSeconds = totalDuration.timeInterval
                if totalSeconds > 0, time.seconds >= totalSeconds {
                    isPlaying = false
                    if let analyticsContext {
                        analyticsService?.track(.audioPlayCompleted(context: analyticsContext))
                    }
                    currentTime = .zero
                    player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
                    nowPlayingManager.clear()
                    deactivatePlaybackSessionIfNeeded()
                }
            }
        }
    }

    private func configureNowPlayingManager() {
        nowPlayingManager.configureHandlers(
            onTogglePlayback: { [weak self] in
                self?.togglePlayback()
            },
            onPlay: { [weak self] in
                guard let self, !self.isPlaying else {
                    return
                }

                self.togglePlayback()
            },
            onPause: { [weak self] in
                self?.pausePlayback()
            },
            onSkipForward: { [weak self] in
                self?.seek(by: .seconds(15))
            },
            onSkipBackward: { [weak self] in
                self?.seek(by: .seconds(-15))
            },
            onSeek: { [weak self] position in
                guard let self else {
                    return
                }

                let clampedProgress: Double
                if self.totalDuration.timeInterval > 0 {
                    clampedProgress = position / self.totalDuration.timeInterval
                } else {
                    clampedProgress = 0
                }
                self.seek(to: clampedProgress)
            }
        )
    }

    private func updateNowPlaying() {
        guard isPlaybackAvailable else {
            nowPlayingManager.clear()
            return
        }

        nowPlayingManager.update(
            title: lectureTitle,
            currentTime: currentTime,
            totalDuration: totalDuration,
            playbackRate: playbackRate,
            isPlaying: isPlaying
        )
    }

    private func isPlayableLocalFile(_ url: URL?) -> Bool {
        guard let url else {
            return false
        }

        guard url.isFileURL else {
            return false
        }

        return fileManager.fileExists(atPath: url.path(percentEncoded: false))
    }

    private func activatePlaybackSessionIfNeeded() {
        do {
            try audioSession.setCategory(
                .playback,
                mode: .spokenAudio,
                policy: .longFormAudio,
                options: []
            )
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
