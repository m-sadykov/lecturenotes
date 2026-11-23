import Foundation

/// Bounds how long the launch splash waits for startup work.
///
/// Startup talks to Firebase and RevenueCat, and some of those calls only return once the
/// server answers. On a slow or filtered network that can take forever, so the splash waits
/// at most `timeout` and lets the work carry on in the background afterwards.
enum StartupDeadline {
    /// How long the splash waits before showing the app anyway.
    static let splashTimeout: Duration = .seconds(3)

    /// Waits for `task` to finish, but no longer than `timeout`.
    ///
    /// The task is never cancelled: if the deadline passes first it keeps running.
    /// A task group can't be used here, since it would wait for the stuck task before returning.
    /// - Returns: `true` when the task finished before the deadline.
    @MainActor
    static func wait(for task: Task<Void, Never>, timeout: Duration) async -> Bool {
        let outcome = Outcome()

        return await withCheckedContinuation { continuation in
            outcome.install(continuation)

            let timer = Task {
                // A cancelled sleep means the task already won, so finishing here is a no-op.
                try? await Task.sleep(for: timeout)
                outcome.finish(finishedInTime: false)
            }

            Task {
                await task.value
                timer.cancel()
                outcome.finish(finishedInTime: true)
            }
        }
    }
}

/// Resumes the waiting continuation exactly once, with whichever side finishes first.
@MainActor
private final class Outcome {
    private var continuation: CheckedContinuation<Bool, Never>?

    func install(_ continuation: CheckedContinuation<Bool, Never>) {
        self.continuation = continuation
    }

    func finish(finishedInTime: Bool) {
        let pending = continuation
        continuation = nil
        pending?.resume(returning: finishedInTime)
    }
}
