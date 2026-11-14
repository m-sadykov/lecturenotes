import FirebaseFunctions
import Foundation

/// Which part of a lecture's study pack to generate again.
enum StudyItemsKind: String, Sendable {
    case flashcards
    case quiz
}

/// A new set returned by the `regenerateStudyItems` function.
enum RegeneratedStudyItems: Sendable {
    case flashcards([Flashcard])
    case quiz([QuizQuestion])

    var isEmpty: Bool {
        switch self {
        case .flashcards(let cards):
            cards.isEmpty
        case .quiz(let questions):
            questions.isEmpty
        }
    }
}

/// Why the backend refused or failed to generate a new set of study items.
enum StudyItemsRegenerationError: LocalizedError, Equatable {
    /// The user's plan doesn't include regeneration; the app offers the paywall instead.
    case planRequired
    /// The lecture already used today's regenerations.
    case dailyLimitReached
    /// The lecture hasn't finished processing, so there is no transcript to generate from.
    case lectureNotReady
    /// Anything else: network, OpenAI or server errors.
    case failed

    /// Maps a `regenerateStudyItems` callable error to a case, using the reason the
    /// function puts in the error details and falling back to the Functions error code.
    init(error: Error) {
        let nsError = error as NSError
        guard nsError.domain == FunctionsErrorDomain else {
            self = .failed
            return
        }

        let details = nsError.userInfo[FunctionsErrorDetailsKey] as? [String: Any]
        switch details?["reason"] as? String {
        case "planRequired":
            self = .planRequired
            return
        case "dailyLimit":
            self = .dailyLimitReached
            return
        case "notReady":
            self = .lectureNotReady
            return
        default:
            break
        }

        switch FunctionsErrorCode(rawValue: nsError.code) {
        case .permissionDenied:
            self = .planRequired
        case .resourceExhausted:
            self = .dailyLimitReached
        case .failedPrecondition:
            self = .lectureNotReady
        default:
            self = .failed
        }
    }

    var errorDescription: String? {
        switch self {
        case .planRequired:
            String(appLocalized: "Upgrade to generate new flashcards and quiz questions.")
        case .dailyLimitReached:
            String(appLocalized: "You can generate a new set for this lecture up to 5 times a day. Try again tomorrow.")
        case .lectureNotReady, .failed:
            String(appLocalized: "Couldn't generate a new set. Try again later.")
        }
    }
}
