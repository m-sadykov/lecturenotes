import Foundation
import Testing
@testable import lecturenotes

@MainActor
struct QuizResultTests {
    @Test(arguments: [
        (10, 10, QuizResultTier.excellent),
        (8, 10, .excellent),
        (7, 10, .good),
        (5, 10, .good),
        (4, 10, .keepPracticing),
        (3, 12, .keepPracticing),
        (0, 0, .keepPracticing),
    ])
    func tierFollowsShareOfCorrectAnswers(correct: Int, total: Int, expected: QuizResultTier) {
        #expect(QuizResultTier(correctCount: correct, totalCount: total) == expected)
    }

    @Test func mistakesListWrongAnswersInQuizOrder() {
        let questions = [
            QuizQuestion(question: "Q1", options: ["A", "B", "C", "D"], correctIndex: 0),
            QuizQuestion(question: "Q2", options: ["A", "B", "C", "D"], correctIndex: 1),
            QuizQuestion(question: "Q3", options: ["A", "B", "C", "D"], correctIndex: 2),
        ]
        let viewModel = QuizViewModel(questions: questions)

        // Q1 wrong, Q2 right, Q3 wrong.
        viewModel.select(optionIndex: 3)
        viewModel.moveToNextQuestion()
        viewModel.select(optionIndex: 1)
        viewModel.moveToNextQuestion()
        viewModel.select(optionIndex: 0)
        viewModel.moveToNextQuestion()

        #expect(viewModel.isFinished)
        #expect(viewModel.resultTier == .keepPracticing)
        #expect(viewModel.mistakes.map(\.question) == ["Q1", "Q3"])
        #expect(viewModel.mistakes.first?.selectedAnswer == "D")
        #expect(viewModel.mistakes.first?.correctAnswer == "A")
        #expect(viewModel.mistakes.last?.selectedAnswer == "A")
        #expect(viewModel.mistakes.last?.correctAnswer == "C")
    }

    @Test func perfectQuizHasNoMistakes() {
        let viewModel = QuizViewModel(questions: [
            QuizQuestion(question: "Q1", options: ["A", "B", "C", "D"], correctIndex: 2),
        ])

        viewModel.select(optionIndex: 2)
        viewModel.moveToNextQuestion()

        #expect(viewModel.mistakes.isEmpty)
        #expect(viewModel.resultTier == .excellent)
    }
}
