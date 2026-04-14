import ActivityKit
import Foundation

@MainActor
final class RecordingLiveActivityManager {
    private var activity: Activity<RecordingLiveActivityAttributes>?
    private let sessionID = UUID().uuidString

    func startOrUpdate(
        phase: RecordingLiveActivityPhase,
        elapsed: Duration,
        limit: Duration
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        let content = ActivityContent(
            state: makeContentState(
                phase: phase,
                elapsed: elapsed,
                limit: limit
            ),
            staleDate: nil
        )

        if let activeActivity = resolvedActivity {
            await activeActivity.update(content)
            activity = activeActivity
            return
        }

        do {
            activity = try Activity.request(
                attributes: RecordingLiveActivityAttributes(sessionID: sessionID),
                content: content,
                pushType: nil
            )
        } catch {
            activity = nil
        }
    }

    func end(
        elapsed: Duration,
        limit: Duration
    ) async {
        guard let activeActivity = resolvedActivity else {
            activity = nil
            return
        }

        let content = ActivityContent(
            state: makeContentState(
                phase: .finishing,
                elapsed: elapsed,
                limit: limit
            ),
            staleDate: .now
        )

        await activeActivity.end(content, dismissalPolicy: .immediate)
        activity = nil
    }

    private var resolvedActivity: Activity<RecordingLiveActivityAttributes>? {
        if let activity {
            return activity
        }

        return Activity<RecordingLiveActivityAttributes>.activities.first
    }

    private func makeContentState(
        phase: RecordingLiveActivityPhase,
        elapsed: Duration,
        limit: Duration
    ) -> RecordingLiveActivityAttributes.ContentState {
        let elapsedSeconds = max(0, Int(elapsed.components.seconds))
        let limitSeconds = max(1, Int(limit.components.seconds))
        let timerStartDate = Date.now.addingTimeInterval(-TimeInterval(elapsedSeconds))

        return RecordingLiveActivityAttributes.ContentState(
            phase: phase,
            elapsedSeconds: elapsedSeconds,
            limitSeconds: limitSeconds,
            timerStartDate: timerStartDate
        )
    }
}

