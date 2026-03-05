import SwiftUI

struct FlashcardsSectionView: View {
    let lecture: Lecture

    var body: some View {
        List {
            Section {
                NavigationLink {
                    FlashcardsPracticeView(viewModel: FlashcardsPracticeViewModel(cards: lecture.flashcards))
                } label: {
                    Label("Start Practice", systemImage: "play.circle")
                }
            }

            if lecture.flashcards.isEmpty {
                Text("Flashcards are not available yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(lecture.flashcards) { card in
                    VStack(alignment: .leading) {
                        Text(card.question)
                            .bold()
                        Text(card.answer)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
