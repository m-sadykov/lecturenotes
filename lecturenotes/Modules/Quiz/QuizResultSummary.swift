import Foundation

/// How a finished quiz went, used for the results headline.
enum QuizResultTier: Equatable {
    /// 80% or more correct.
    case excellent
    /// 50–79% correct.
    case good
    /// Below 50%.
    case keepPracticing

    init(correctCount: Int, totalCount: Int) {
        guard totalCount > 0 else {
            self = .keepPracticing
            return
        }

        let share = Double(correctCount) / Double(totalCount)
        if share >= 0.8 {
            self = .excellent
        } else if share >= 0.5 {
            self = .good
        } else {
            self = .keepPracticing
        }
    }

    var headline: LocalizedStringResource {
        switch self {
        case .excellent:
            "Excellent!"
        case .good:
            "Good result"
        case .keepPracticing:
            "Keep practicing"
        }
    }
}

/// A question answered wrongly, shown in the results' mistakes review.
struct QuizMistake: Identifiable, Equatable {
    let id: QuizQuestion.ID
    let question: String
    let selectedAnswer: String
    let correctAnswer: String
}
