import Foundation
import Observation

@MainActor
@Observable
final class FlashcardsPracticeViewModel {
    private(set) var cards: [Flashcard]
    let regeneration: StudyItemsRegenerationModel<Flashcard>

    var currentIndex = 0
    var isShowingAnswer = false
    @ObservationIgnored private let analyticsService: AppAnalyticsService?
    @ObservationIgnored private let analyticsContext: LectureAnalyticsContext?

    init(
        cards: [Flashcard],
        analyticsService: AppAnalyticsService? = nil,
        analyticsContext: LectureAnalyticsContext? = nil,
        regeneration: StudyItemsRegenerationModel<Flashcard>? = nil
    ) {
        self.cards = cards
        self.regeneration = regeneration ?? .unavailable
        self.analyticsService = analyticsService
        self.analyticsContext = analyticsContext
    }

    var hasCards: Bool {
        !cards.isEmpty
    }

    var pageCount: Int {
        cards.count
    }

    func flipCard() {
        isShowingAnswer.toggle()
        if let analyticsContext {
            analyticsService?.track(
                .flashcardFlipped(
                    context: analyticsContext,
                    cardIndex: currentIndex,
                    isShowingAnswer: isShowingAnswer
                )
            )
            if isShowingAnswer, currentIndex == max(cards.count - 1, 0) {
                analyticsService?.track(
                    .flashcardsCompleted(
                        context: analyticsContext,
                        cardsCount: cards.count
                    )
                )
            }
        }
    }

    func showCard(at index: Int) {
        guard cards.indices.contains(index) else {
            return
        }
        currentIndex = index
        isShowingAnswer = false
    }

    /// Replaces the deck with a newly generated one and starts again from the first card.
    func generateNewSet() async {
        guard let newCards = await regeneration.generate() else {
            return
        }

        replaceCards(newCards)
    }

    func replaceCards(_ newCards: [Flashcard]) {
        cards = newCards
        currentIndex = 0
        isShowingAnswer = false
    }

    func trackStarted() {
        guard let analyticsContext else {
            return
        }

        analyticsService?.track(
            .flashcardsStarted(
                context: analyticsContext,
                cardsCount: cards.count
            )
        )
    }
}
