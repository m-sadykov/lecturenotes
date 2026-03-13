import Foundation
import Observation

@MainActor
@Observable
final class FlashcardsPracticeViewModel {
    let cards: [Flashcard]

    var currentIndex = 0
    var isShowingAnswer = false

    init(cards: [Flashcard]) {
        self.cards = cards
    }

    var hasCards: Bool {
        !cards.isEmpty
    }

    var pageCount: Int {
        cards.count
    }

    func flipCard() {
        isShowingAnswer.toggle()
    }

    func showCard(at index: Int) {
        guard cards.indices.contains(index) else {
            return
        }
        currentIndex = index
        isShowingAnswer = false
    }
}
