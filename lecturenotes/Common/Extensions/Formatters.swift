import Foundation

enum LectureFormatters {
    static let date: Date.FormatStyle = .dateTime.month(.abbreviated).day().year()
    static let dayMonthYear: Date.FormatStyle = .dateTime.day().month(.abbreviated).year()

    static func durationText(_ duration: Duration) -> String {
        let components = duration.components
        let totalSeconds = max(0, Int(components.seconds))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes)m \(seconds)s"
    }

    static func clockText(_ duration: Duration) -> String {
        duration.formatted(.time(pattern: .minuteSecond))
    }
}
