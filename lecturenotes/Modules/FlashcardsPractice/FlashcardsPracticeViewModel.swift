import Foundation
import Observation

@MainActor
@Observable
final class FlashcardsPracticeViewModel {
    let cards: [Flashcard]

    var currentIndex = 0
    var isShowingAnswer = false
    @ObservationIgnored private let analyticsService: AppAnalyticsService?
    @ObservationIgnored private let analyticsContext: LectureAnalyticsContext?

    init(
        cards: [Flashcard],
        analyticsService: AppAnalyticsService? = nil,
        analyticsContext: LectureAnalyticsContext? = nil
    ) {
        self.cards = cards
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
