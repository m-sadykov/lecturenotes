import Foundation
import Testing
@testable import lecturenotes

/// Covers the splash deadline that keeps a stuck startup from hiding the app.
@MainActor
struct StartupDeadlineTests {
    @Test func reportsWorkThatFinishesInTime() async {
        let task = Task<Void, Never> {}

        let finishedInTime = await StartupDeadline.wait(for: task, timeout: .seconds(5))

        #expect(finishedInTime)
    }

    @Test func stopsWaitingForWorkThatNeverFinishes() async {
        let task = Task<Void, Never> {
            try? await Task.sleep(for: .seconds(60))
        }
        let start = ContinuousClock.now

        let finishedInTime = await StartupDeadline.wait(for: task, timeout: .milliseconds(100))

        #expect(finishedInTime == false)
        #expect(ContinuousClock.now - start < .seconds(5))
        task.cancel()
    }

    @Test func leavesSlowWorkRunningAfterTheDeadline() async {
        let task = Task<Void, Never> {
            try? await Task.sleep(for: .milliseconds(300))
        }

        _ = await StartupDeadline.wait(for: task, timeout: .milliseconds(50))

        #expect(task.isCancelled == false)
        await task.value
    }
}
