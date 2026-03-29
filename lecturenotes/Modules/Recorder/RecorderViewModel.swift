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
    @ObservationIgnored private var timerTask: Task<Void, Never>?

    init(limit: Duration = .seconds(300)) {
        self.limit = limit
        self.recordingManager = RecordingManager()
        bindRecordingManager()
    }

    init(limit: Duration = .seconds(300), recordingManager: RecordingManager) {
        self.limit = limit
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func record() {
        mode = .recording
        startTimerIfNeeded()
    }

    func pause() {
        guard mode == .recording else { return }
        recordingManager.pauseRecording()
        syncElapsedWithRecording()
        mode = .paused
    }

    func resume() {
        guard mode == .paused else { return }
        recordingManager.resumeRecording()
        mode = .recording
        startTimerIfNeeded()
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
    }

    func finishRecording() -> RecordingDraft? {
        syncElapsedWithRecording()
        mode = .finished
        timerTask?.cancel()
        timerTask = nil

        guard let recording = recordingManager.stopRecording() else {
            return nil
        }

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
        }
    }
}
