import Foundation
import Observation

@MainActor
@Observable
final class FlashcardsPracticeViewModel {
    let cards: [Flashcard]

    var currentIndex = 0
    var knownCount = 0
    var unknownCount = 0
    var isShowingAnswer = false

    init(cards: [Flashcard]) {
        self.cards = cards
    }

    var currentCard: Flashcard? {
        guard cards.indices.contains(currentIndex) else { return nil }
        return cards[currentIndex]
    }

    var progressText: String {
        guard !cards.isEmpty else { return "0/0" }
        return "\(min(currentIndex + 1, cards.count))/\(cards.count)"
    }

    var isFinished: Bool {
        currentIndex >= cards.count
    }

    func flipCard() {
        isShowingAnswer.toggle()
    }

    func markKnown() {
        knownCount += 1
        moveNext()
    }

    func markUnknown() {
        unknownCount += 1
        moveNext()
    }

    private func moveNext() {
        isShowingAnswer = false
        currentIndex += 1
    }
}
