import FirebaseFunctions
import Foundation
import Testing
@testable import lecturenotes

@MainActor
struct StudyItemsRegenerationTests {
    private let oldCards = [Flashcard(question: "Old?", answer: "Old.")]
    private let newCards = [Flashcard(question: "New?", answer: "New."), Flashcard(question: "Next?", answer: "Next.")]
    private let newQuestions = [QuizQuestion(question: "New?", options: ["A", "B", "C", "D"], correctIndex: 2)]

    private func functionsError(_ code: FunctionsErrorCode, reason: String? = nil) -> NSError {
        var userInfo: [String: Any] = [:]
        if let reason {
            userInfo[FunctionsErrorDetailsKey] = ["reason": reason]
        }
        return NSError(domain: FunctionsErrorDomain, code: code.rawValue, userInfo: userInfo)
    }

    // MARK: Error mapping

    @Test func mapsReasonsFromErrorDetails() {
        #expect(StudyItemsRegenerationError(error: functionsError(.permissionDenied, reason: "planRequired")) == .planRequired)
        #expect(StudyItemsRegenerationError(error: functionsError(.resourceExhausted, reason: "dailyLimit")) == .dailyLimitReached)
        #expect(StudyItemsRegenerationError(error: functionsError(.failedPrecondition, reason: "notReady")) == .lectureNotReady)
    }

    @Test func fallsBackToFunctionsErrorCode() {
        #expect(StudyItemsRegenerationError(error: functionsError(.resourceExhausted)) == .dailyLimitReached)
        #expect(StudyItemsRegenerationError(error: functionsError(.permissionDenied)) == .planRequired)
        #expect(StudyItemsRegenerationError(error: functionsError(.internal)) == .failed)
    }

    @Test func otherErrorsAreFailures() {
        let networkError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)

        #expect(StudyItemsRegenerationError(error: networkError) == .failed)
    }

    // MARK: Regeneration model

    @Test func upgradeRequiredGoesToPaywallInsteadOfConfirming() {
        var upgradeRequests = 0
        let model = StudyItemsRegenerationModel<Flashcard>(
            access: .upgradeRequired,
            regenerate: { [] },
            onUpgradeRequested: { upgradeRequests += 1 }
        )

        model.requestNewSet()

        #expect(upgradeRequests == 1)
        #expect(model.isConfirmationPresented == false)
    }

    @Test func availableAsksForConfirmation() {
        let model = StudyItemsRegenerationModel<Flashcard>(access: .available, regenerate: { [] }, onUpgradeRequested: {})

        model.requestNewSet()

        #expect(model.isConfirmationPresented)
    }

    @Test func unavailableIsNotOffered() async {
        let model = StudyItemsRegenerationModel<Flashcard>.unavailable

        model.requestNewSet()

        #expect(model.isOffered == false)
        #expect(model.isConfirmationPresented == false)
        #expect(await model.generate() == nil)
    }

    @Test func dailyLimitErrorIsShown() async {
        let model = StudyItemsRegenerationModel<Flashcard>(
            access: .available,
            regenerate: { throw StudyItemsRegenerationError.dailyLimitReached },
            onUpgradeRequested: {}
        )

        let result = await model.generate()

        #expect(result == nil)
        #expect(model.error == .dailyLimitReached)
        #expect(model.isRegenerating == false)
    }

    @Test func planErrorFromBackendOpensPaywall() async {
        var upgradeRequests = 0
        let model = StudyItemsRegenerationModel<Flashcard>(
            access: .available,
            regenerate: { throw StudyItemsRegenerationError.planRequired },
            onUpgradeRequested: { upgradeRequests += 1 }
        )

        _ = await model.generate()

        #expect(upgradeRequests == 1)
        #expect(model.error == nil)
    }

    // MARK: Screens

    @Test func flashcardsNewSetReplacesDeckAndRestarts() async {
        let newCards = newCards
        let viewModel = FlashcardsPracticeViewModel(
            cards: oldCards,
            regeneration: StudyItemsRegenerationModel(access: .available, regenerate: { newCards }, onUpgradeRequested: {})
        )
        viewModel.showCard(at: 0)
        viewModel.flipCard()

        await viewModel.generateNewSet()

        #expect(viewModel.cards.map(\.question) == ["New?", "Next?"])
        #expect(viewModel.currentIndex == 0)
        #expect(viewModel.isShowingAnswer == false)
    }

    @Test func failedFlashcardsRegenerationKeepsDeck() async {
        let viewModel = FlashcardsPracticeViewModel(
            cards: oldCards,
            regeneration: StudyItemsRegenerationModel(
                access: .available,
                regenerate: { throw StudyItemsRegenerationError.failed },
                onUpgradeRequested: {}
            )
        )

        await viewModel.generateNewSet()

        #expect(viewModel.cards.map(\.question) == ["Old?"])
        #expect(viewModel.regeneration.error == .failed)
    }

    @Test func quizNewSetClearsAnswers() async {
        let newQuestions = newQuestions
        let viewModel = QuizViewModel(
            questions: [QuizQuestion(question: "Old?", options: ["A", "B", "C", "D"], correctIndex: 0)],
            regeneration: StudyItemsRegenerationModel(access: .available, regenerate: { newQuestions }, onUpgradeRequested: {})
        )
        viewModel.select(optionIndex: 0)
        viewModel.moveToNextQuestion()
        #expect(viewModel.isFinished)

        await viewModel.generateNewSet()

        #expect(viewModel.questions.map(\.question) == ["New?"])
        #expect(viewModel.isFinished == false)
        #expect(viewModel.questionsAnsweredCount == 0)
        #expect(viewModel.currentIndex == 0)
    }

    // MARK: Plans

    @Test(arguments: [AppUserPlan.premium, .pro])
    func paidPlansCanRegenerate(plan: AppUserPlan) {
        #expect(plan.canRegenerateStudyItems)
    }

    @Test func freemiumCannotRegenerate() {
        #expect(AppUserPlan.freemium.canRegenerateStudyItems == false)
    }

    @Test func detailScreenWithoutBackendDoesNotOfferRegeneration() {
        let lecture = Lecture(
            title: "Lecture",
            createdAt: .now,
            duration: .seconds(60),
            status: .ready,
            transcript: "Text",
            summaryShort: "",
            summaryLong: "",
            flashcards: oldCards,
            quiz: []
        )
        let viewModel = LectureDetailViewModel(lecture: lecture, repository: SpyLectureRepository())

        let access: StudyItemsRegenerationModel<Flashcard>.Access = viewModel.studyItemsRegenerationAccess(plan: .pro)

        #expect(access == .unavailable)
    }
}
