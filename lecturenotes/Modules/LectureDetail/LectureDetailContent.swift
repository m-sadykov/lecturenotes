import SwiftUI

/// A piece of generated study content on the lecture detail screen.
enum LectureDetailContent: Hashable, CaseIterable {
    case summary
    case transcript
    case keyPoints
    case flashcards
    case quiz

    var titleResource: LocalizedStringResource {
        switch self {
        case .summary:
            "Summary"
        case .transcript:
            "Transcript"
        case .keyPoints:
            "Key Points"
        case .flashcards:
            "Flashcards"
        case .quiz:
            "Quiz"
        }
    }

    var systemImage: String {
        switch self {
        case .summary:
            "doc.richtext"
        case .transcript:
            "text.alignleft"
        case .keyPoints:
            "list.bullet.rectangle"
        case .flashcards:
            "rectangle.on.rectangle.angled"
        case .quiz:
            "checklist"
        }
    }

    /// Kept identical to the former section names so existing analytics stay comparable.
    var analyticsValue: String {
        switch self {
        case .summary:
            "summary"
        case .transcript:
            "transcript"
        case .keyPoints:
            "key_points"
        case .flashcards:
            "flashcards"
        case .quiz:
            "quiz"
        }
    }

    func copyableText(for lecture: Lecture, summaryText: String) -> String? {
        let text = switch self {
        case .summary:
            summaryText
        case .transcript:
            lecture.transcript
        case .keyPoints:
            lecture.keyPoints
        case .flashcards, .quiz:
            ""
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
    }

    /// Short status line for the action tile, e.g. "12 cards". Returned as a resource and
    /// resolved by `Text`, so it follows the in-app language override like other labels
    /// (`String(localized:)` would use the system language).
    func detailText(for lecture: Lecture) -> LocalizedStringResource? {
        switch self {
        case .flashcards:
            lecture.flashcards.isEmpty ? nil : "\(lecture.flashcards.count) cards"
        case .quiz:
            lecture.quiz.isEmpty ? nil : "\(lecture.quiz.count) questions"
        case .keyPoints, .summary, .transcript:
            nil
        }
    }

    /// Study tools shown in the lecture detail grid, in display order, without the ones
    /// the lecture has no content for.
    static func studyTools(for lecture: Lecture) -> [LectureDetailContent] {
        [.transcript, .flashcards, .quiz, .keyPoints].filter { $0.isAvailable(for: lecture) }
    }

    func isAvailable(for lecture: Lecture) -> Bool {
        switch self {
        case .summary:
            !lecture.summaryNote.isEmpty || !lecture.summaryLong.isEmpty || !lecture.summaryShort.isEmpty
        case .transcript:
            !lecture.transcript.isEmpty
        case .keyPoints:
            !lecture.keyPoints.isEmpty
        case .flashcards:
            !lecture.flashcards.isEmpty
        case .quiz:
            !lecture.quiz.isEmpty
        }
    }
}
