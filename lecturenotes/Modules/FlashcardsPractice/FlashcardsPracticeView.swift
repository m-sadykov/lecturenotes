import SwiftUI

struct FlashcardsPracticeView: View {
    @State var viewModel: FlashcardsPracticeViewModel

    var body: some View {
        VStack {
            Text("Progress: \(viewModel.progressText)")
                .foregroundStyle(.secondary)

            if viewModel.isFinished {
                VStack {
                    Text("Practice completed")
                        .bold()
                    Text("Known: \(viewModel.knownCount)")
                    Text("Don't know: \(viewModel.unknownCount)")
                }
            } else if let card = viewModel.currentCard {
                FlashcardCardView(text: viewModel.isShowingAnswer ? card.answer : card.question)

                Button(viewModel.isShowingAnswer ? "Show Question" : "Show Answer", systemImage: "arrow.triangle.2.circlepath") {
                    viewModel.flipCard()
                }

                HStack {
                    Button("Know", systemImage: "checkmark.circle") {
                        viewModel.markKnown()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Don't know", systemImage: "xmark.circle") {
                        viewModel.markUnknown()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Text("No flashcards available")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Flashcards")
    }
}

#Preview {
    NavigationStack {
        FlashcardsPracticeView(viewModel: FlashcardsPracticeViewModel(cards: MockLectures.makeLectures()[0].flashcards))
    }
}
