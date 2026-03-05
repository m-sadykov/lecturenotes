import Foundation
import Observation

@MainActor
@Observable
final class QuizViewModel {
    let questions: [QuizQuestion]

    var currentIndex = 0
    var score = 0
    var selectedIndex: Int?

    init(questions: [QuizQuestion]) {
        self.questions = questions
    }

    var currentQuestion: QuizQuestion? {
        guard questions.indices.contains(currentIndex) else { return nil }
        return questions[currentIndex]
    }

    var progressText: String {
        guard !questions.isEmpty else { return "0/0" }
        return "\(min(currentIndex + 1, questions.count))/\(questions.count)"
    }

    var isFinished: Bool {
        currentIndex >= questions.count
    }

    func select(optionIndex: Int) {
        selectedIndex = optionIndex
    }

    func submitAndMoveNext() {
        guard let question = currentQuestion, let selectedIndex else { return }
        if selectedIndex == question.correctIndex {
            score += 1
        }
        self.selectedIndex = nil
        currentIndex += 1
    }
}
