import Foundation

enum LectureFormatters {
    static let date: Date.FormatStyle = .dateTime.month(.abbreviated).day().year()
    static let dayMonthYear: Date.FormatStyle = .dateTime.day().month(.abbreviated).year()

    static func durationText(_ duration: Duration) -> String {
        duration.formatted(
            .units(
                allowed: [.hours, .minutes, .seconds],
                width: .abbreviated,
                maximumUnitCount: 2
            )
        )
    }

    static func clockText(_ duration: Duration) -> String {
        duration.formatted(.time(pattern: .minuteSecond))
    }
}
