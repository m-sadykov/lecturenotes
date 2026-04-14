import Foundation
import Observation

@MainActor
@Observable
final class RecorderViewModel {
    enum SaveValidationError: LocalizedError {
        case tooShort(minimumDuration: Duration)

        var errorDescription: String? {
            switch self {
            case .tooShort(let minimumDuration):
                String(localized: "Record at least \(Int(minimumDuration.components.seconds)) seconds to save.")
            }
        }
    }

    struct RecordingDraft {
        let audioURL: URL
        let createdAt: Date
        let duration: Duration
    }

    enum Mode {
        case idle
        case recording
        case paused
        case finished
    }

    var mode: Mode = .idle
    var elapsed: Duration = .zero
    var limit: Duration = .seconds(300)
    var errorMessage: String?

    @ObservationIgnored private let recordingManager: RecordingManager
    @ObservationIgnored private let analyticsService: AppAnalyticsService?
    @ObservationIgnored private let crashReportingService: CrashReportingService?
    @ObservationIgnored private let recordingLiveActivityManager: RecordingLiveActivityManager
    @ObservationIgnored private let plan: AppUserPlan?
    @ObservationIgnored private var timerTask: Task<Void, Never>?

    init(
        limit: Duration = .seconds(300),
        analyticsService: AppAnalyticsService? = nil,
        crashReportingService: CrashReportingService? = nil,
        recordingLiveActivityManager: RecordingLiveActivityManager? = nil,
        plan: AppUserPlan? = nil
    ) {
        self.limit = limit
        self.analyticsService = analyticsService
        self.crashReportingService = crashReportingService
        self.recordingLiveActivityManager = recordingLiveActivityManager ?? RecordingLiveActivityManager()
        self.plan = plan
        self.recordingManager = RecordingManager()
        bindRecordingManager()
    }

    init(
        limit: Duration = .seconds(300),
        recordingManager: RecordingManager,
        analyticsService: AppAnalyticsService? = nil,
        crashReportingService: CrashReportingService? = nil,
        recordingLiveActivityManager: RecordingLiveActivityManager? = nil,
        plan: AppUserPlan? = nil
    ) {
        self.limit = limit
        self.analyticsService = analyticsService
        self.crashReportingService = crashReportingService
        self.recordingLiveActivityManager = recordingLiveActivityManager ?? RecordingLiveActivityManager()
        self.plan = plan
        self.recordingManager = recordingManager
        bindRecordingManager()
    }

    var progress: Double {
        let limitSeconds = max(1, Int(limit.components.seconds))
        let elapsedSeconds = max(0, Int(elapsed.components.seconds))
        return min(1, Double(elapsedSeconds) / Double(limitSeconds))
    }

    var canTogglePause: Bool {
        mode == .recording || mode == .paused
    }

    func syncElapsedWithRecording() {
        let currentDuration = recordingManager.currentDuration
        if currentDuration > elapsed {
            elapsed = currentDuration
        }
    }

    func handleAppDidBecomeActive() {
        recordingManager.refreshAfterForeground()
        syncElapsedWithRecording()

        guard mode == .recording, !recordingManager.isRecording else {
            return
        }

        mode = .paused
        errorMessage = String(localized: "Recording was paused by the system.")
        syncLiveActivity()
        crashReportingService?.breadcrumb(
            "recording_session_interrupted",
            metadata: [
                "elapsed_seconds": elapsed.secondsValue,
                "interruption_reason": "app_became_active_without_recording",
            ]
        )
    }

    func handleAppDidEnterBackground() {
        guard mode == .recording else {
            return
        }

        syncElapsedWithRecording()
        recordingManager.prepareForBackgroundRecording()
    }

    func start() async {
        guard mode == .idle else { return }

        do {
            try await recordingManager.startRecording()
            record()
            crashReportingService?.setCurrentFlow("recording")
            crashReportingService?.breadcrumb("recording_session_started")
            analyticsService?.track(
                .recordStarted(
                    limitMinutes: limit.minutesValue,
                    plan: plan
                )
            )
        } catch {
            errorMessage = error.localizedDescription
            crashReportingService?.recordNonFatal(
                error,
                reason: "recording_start_failed",
                metadata: [
                    "limit_minutes": limit.minutesValue,
                ]
            )
        }
    }

    func record() {
        mode = .recording
        startTimerIfNeeded()
        syncLiveActivity()
    }

    func pause() {
        guard mode == .recording else { return }
        recordingManager.pauseRecording()
        syncElapsedWithRecording()
        mode = .paused
        syncLiveActivity()
        analyticsService?.track(.recordPaused(elapsedSeconds: elapsed.secondsValue))
    }

    func resume() {
        guard mode == .paused else { return }
        recordingManager.resumeRecording()
        mode = .recording
        startTimerIfNeeded()
        syncLiveActivity()
        analyticsService?.track(.recordResumed(elapsedSeconds: elapsed.secondsValue))
    }

    func togglePause() {
        switch mode {
        case .recording:
            pause()
        case .paused:
            resume()
        case .idle, .finished:
            break
        }
    }

    func stop() {
        syncElapsedWithRecording()
        mode = .finished
        timerTask?.cancel()
        timerTask = nil
        _ = recordingManager.stopRecording()
        endLiveActivity()
        analyticsService?.track(
            .recordFinished(
                elapsedSeconds: elapsed.secondsValue,
                finishReason: "limit_reached"
            )
        )
    }

    func finishRecording() -> RecordingDraft? {
        syncElapsedWithRecording()
        mode = .finished
        timerTask?.cancel()
        timerTask = nil

        guard let recording = recordingManager.stopRecording() else {
            return nil
        }

        endLiveActivity(elapsed: recording.duration)
        analyticsService?.track(
            .recordFinished(
                elapsedSeconds: recording.duration.secondsValue,
                finishReason: "user_saved"
            )
        )

        return RecordingDraft(
            audioURL: recording.url,
            createdAt: recording.createdAt,
            duration: max(.seconds(1), recording.duration)
        )
    }

    func stopAndDiscard() {
        syncElapsedWithRecording()
        mode = .finished
        timerTask?.cancel()
        timerTask = nil
        recordingManager.discardRecording()
        endLiveActivity()
        analyticsService?.track(
            .recordFinished(
                elapsedSeconds: elapsed.secondsValue,
                finishReason: "discarded"
            )
        )
    }

    private func startTimerIfNeeded() {
        guard timerTask == nil || timerTask?.isCancelled == true else { return }

        timerTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                syncElapsedWithRecording()
                guard mode == .recording else { continue }
                guard recordingManager.isRecording else {
                    mode = .paused
                    errorMessage = String(localized: "Recording was paused by the system.")
                    crashReportingService?.breadcrumb(
                        "recording_session_interrupted",
                        metadata: [
                            "elapsed_seconds": elapsed.secondsValue,
                            "interruption_reason": "recording_manager_not_recording",
                        ]
                    )
                    syncLiveActivity()
                    continue
                }
                if elapsed >= limit {
                    stop()
                }
            }
        }
    }

    private func bindRecordingManager() {
        recordingManager.onSystemPause = { [weak self] message in
            guard let self else {
                return
            }

            self.syncElapsedWithRecording()

            if self.mode == .recording {
                self.mode = .paused
            }

            self.errorMessage = message
            self.syncLiveActivity()
            self.crashReportingService?.breadcrumb(
                "recording_session_interrupted",
                metadata: [
                    "elapsed_seconds": self.elapsed.secondsValue,
                    "interruption_reason": message,
                ]
            )
        }
    }

    private func syncLiveActivity() {
        let phase: RecordingLiveActivityPhase

        switch mode {
        case .idle, .finished:
            return
        case .recording:
            phase = .recording
        case .paused:
            phase = .paused
        }

        let elapsed = self.elapsed
        let limit = self.limit
        Task {
            await recordingLiveActivityManager.startOrUpdate(
                phase: phase,
                elapsed: elapsed,
                limit: limit
            )
        }
    }

    private func endLiveActivity(elapsed: Duration? = nil) {
        let resolvedElapsed = elapsed ?? self.elapsed
        let limit = self.limit
        Task {
            await recordingLiveActivityManager.end(
                elapsed: resolvedElapsed,
                limit: limit
            )
        }
    }
}

private extension Duration {
    var minutesValue: Double {
        secondsValue / 60
    }

    var secondsValue: Double {
        TimeInterval(components.seconds) + (TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000)
    }
}
