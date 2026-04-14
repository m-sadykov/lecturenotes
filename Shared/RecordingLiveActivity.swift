import Foundation

#if canImport(ActivityKit)
import ActivityKit

struct RecordingLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        var phase: RecordingLiveActivityPhase
        var elapsedSeconds: Int
        var limitSeconds: Int
        var timerStartDate: Date
    }

    var sessionID: String
}
#endif

enum RecordingLiveActivityPhase: String, Codable, Hashable, Sendable {
    case recording
    case paused
    case finishing

    var statusText: String {
        switch self {
        case .recording:
            String(localized: "Recording lecture")
        case .paused:
            String(localized: "Recording paused")
        case .finishing:
            String(localized: "Saving recording...")
        }
    }

    var detailText: String {
        switch self {
        case .recording:
            String(localized: "In progress")
        case .paused:
            String(localized: "Paused")
        case .finishing:
            String(localized: "Finishing")
        }
    }

    var systemImageName: String {
        switch self {
        case .recording:
            "waveform"
        case .paused:
            "pause.fill"
        case .finishing:
            "checkmark.circle.fill"
        }
    }
}

enum RecordingLiveActivityRouteAction: String, Sendable {
    case show
    case finish
}

enum RecordingLiveActivityRoute {
    static let scheme = "lectraai"
    static let host = "recording"

    static func url(for action: RecordingLiveActivityRouteAction) -> URL {
        URL(string: "\(scheme)://\(host)/\(action.rawValue)")!
    }

    static func action(from url: URL) -> RecordingLiveActivityRouteAction? {
        guard url.scheme?.localizedLowercase == scheme,
              url.host?.localizedLowercase == host else {
            return nil
        }

        let pathComponent = url.pathComponents.dropFirst().first ?? RecordingLiveActivityRouteAction.show.rawValue
        return RecordingLiveActivityRouteAction(rawValue: pathComponent)
    }
}
