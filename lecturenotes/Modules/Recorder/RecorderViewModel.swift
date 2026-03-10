import Foundation
import Observation

@MainActor
@Observable
final class RecorderViewModel {
    enum Mode {
        case idle
        case recording
        case paused
        case finished
    }

    var mode: Mode = .idle
    var courseName = "Biology 101"
    var elapsed: Duration = .zero
    var limit: Duration = .seconds(600)
    var errorMessage: String?

    private let recordingManager: RecordingManager
    private var timerTask: Task<Void, Never>?

    init() {
        self.recordingManager = RecordingManager()
    }

    init(recordingManager: RecordingManager) {
        self.recordingManager = recordingManager
    }

    var progress: Double {
        let limitSeconds = max(1, Int(limit.components.seconds))
        let elapsedSeconds = max(0, Int(elapsed.components.seconds))
        return min(1, Double(elapsedSeconds) / Double(limitSeconds))
    }

    var canTogglePause: Bool {
        mode == .recording || mode == .paused
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
        mode = .finished
        timerTask?.cancel()
        timerTask = nil
        recordingManager.stopRecording()
    }

    func stopAndDiscard() {
        stop()
    }

    private func startTimerIfNeeded() {
        guard timerTask == nil || timerTask?.isCancelled == true else { return }

        timerTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard mode == .recording else { continue }
                elapsed += .seconds(1)
                if elapsed >= limit {
                    stop()
                }
            }
        }
    }
}
