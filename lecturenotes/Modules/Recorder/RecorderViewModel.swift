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

    private var timerTask: Task<Void, Never>?

    func record() {
        mode = .recording
        startTimerIfNeeded()
    }

    func pause() {
        guard mode == .recording else { return }
        mode = .paused
    }

    func resume() {
        guard mode == .paused else { return }
        mode = .recording
        startTimerIfNeeded()
    }

    func stop() {
        mode = .finished
        timerTask?.cancel()
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
