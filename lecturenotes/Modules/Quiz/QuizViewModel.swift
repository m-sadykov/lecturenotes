import Foundation
import Observation

@MainActor
@Observable
final class QuizViewModel {
    private(set) var questions: [QuizQuestion]
    let regeneration: StudyItemsRegenerationModel<QuizQuestion>

    var currentIndex = 0
    private var answersByQuestionIndex: [Int: Int] = [:]
    @ObservationIgnored private let analyticsService: AppAnalyticsService?
    @ObservationIgnored private let analyticsContext: LectureAnalyticsContext?

    init(
        questions: [QuizQuestion],
        analyticsService: AppAnalyticsService? = nil,
        analyticsContext: LectureAnalyticsContext? = nil,
        regeneration: StudyItemsRegenerationModel<QuizQuestion>? = nil
    ) {
        self.questions = questions
        self.regeneration = regeneration ?? .unavailable
        self.analyticsService = analyticsService
        self.analyticsContext = analyticsContext
    }

    var hasQuestions: Bool {
        !questions.isEmpty
    }

    var progressValue: Double {
        guard !questions.isEmpty else {
            return 0
        }
        return Double(min(currentIndex + 1, questions.count)) / Double(questions.count)
    }

    var isFinished: Bool {
        currentIndex >= questions.count
    }

    var progressText: String {
        guard !questions.isEmpty else {
            return "0/0"
        }
        return "\(min(currentIndex + 1, questions.count))/\(questions.count)"
    }

    var correctCount: Int {
        answersByQuestionIndex.reduce(into: 0) { result, entry in
            let (questionIndex, selectedIndex) = entry
            guard questions.indices.contains(questionIndex) else {
                return
            }
            if questions[questionIndex].correctIndex == selectedIndex {
                result += 1
            }
        }
    }

    var wrongCount: Int {
        max(questionsAnsweredCount - correctCount, 0)
    }

    var questionsAnsweredCount: Int {
        answersByQuestionIndex.count
    }

    var currentQuestion: QuizQuestion? {
        guard questions.indices.contains(currentIndex) else {
            return nil
        }
        return questions[currentIndex]
    }

    var hasAnsweredCurrentQuestion: Bool {
        selectedIndex != nil
    }

    var selectedIndex: Int? {
        answersByQuestionIndex[currentIndex]
    }

    var lastAnswerWasCorrect: Bool? {
        guard let selectedIndex else {
            return nil
        }
        guard let currentQuestion else {
            return nil
        }
        return selectedIndex == currentQuestion.correctIndex
    }

    func select(optionIndex: Int) {
        guard currentQuestion != nil, selectedIndex == nil else {
            return
        }

        answersByQuestionIndex[currentIndex] = optionIndex
        if let analyticsContext, let currentQuestion {
            analyticsService?.track(
                .quizAnswered(
                    context: analyticsContext,
                    questionIndex: currentIndex,
                    isCorrect: optionIndex == currentQuestion.correctIndex
                )
            )
        }
    }

    func moveToNextQuestion() {
        guard selectedIndex != nil else {
            return
        }

        currentIndex += 1
        if currentIndex >= questions.count, let analyticsContext {
            analyticsService?.track(
                .quizCompleted(
                    context: analyticsContext,
                    correctCount: correctCount,
                    wrongCount: wrongCount,
                    totalCount: questions.count
                )
            )
        }
    }

    func showQuestion(at index: Int) {
        guard questions.indices.contains(index) else {
            return
        }
        currentIndex = index
    }

    /// Replaces the quiz with newly generated questions and starts it over.
    func generateNewSet() async {
        guard let newQuestions = await regeneration.generate() else {
            return
        }

        replaceQuestions(newQuestions)
    }

    func replaceQuestions(_ newQuestions: [QuizQuestion]) {
        questions = newQuestions
        answersByQuestionIndex = [:]
        currentIndex = 0
    }

    func trackStarted() {
        guard let analyticsContext else {
            return
        }

        analyticsService?.track(
            .quizStarted(
                context: analyticsContext,
                questionCount: questions.count
            )
        )
    }
}
