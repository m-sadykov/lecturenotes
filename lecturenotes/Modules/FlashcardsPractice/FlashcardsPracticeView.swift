import SwiftUI

struct FlashcardsPracticeView: View {
    @State var viewModel: FlashcardsPracticeViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()

            if viewModel.hasCards {
                VStack(spacing: 0) {
                    TabView(selection: $viewModel.currentIndex) {
                        ForEach(viewModel.cards.enumerated(), id: \.element.id) { index, card in
                            FlashcardCarouselCardView(
                                question: card.question,
                                answer: card.answer,
                                isShowingAnswer: viewModel.currentIndex == index && viewModel.isShowingAnswer,
                                onTap: {
                                    viewModel.flipCard()
                                }
                            )
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                            .padding(.bottom, 32)
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: viewModel.currentIndex, initial: false) { _, newIndex in
                        viewModel.showCard(at: newIndex)
                    }

                    FlashcardsPageIndicator(
                        pageCount: viewModel.pageCount,
                        currentIndex: viewModel.currentIndex
                    )
                    .padding(.bottom, 28)
                }
            } else {
                Text("No flashcards available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close", systemImage: "xmark") {
                    dismiss()
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(.primary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        FlashcardsPracticeView(viewModel: FlashcardsPracticeViewModel(cards: MockLectures.makeLectures()[0].flashcards))
    }
}

private struct FlashcardCarouselCardView: View {
    let question: String
    let answer: String
    let isShowingAnswer: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                FlashcardFaceView(
                    emoji: "❓",
                    text: question,
                    footerText: "Tap on card to rotate"
                )
                .opacity(isShowingAnswer ? 0 : 1)
                .rotation3DEffect(
                    .degrees(isShowingAnswer ? -180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )

                FlashcardFaceView(
                    emoji: "✔️",
                    text: answer,
                    footerText: "Tap on card to rotate"
                )
                .opacity(isShowingAnswer ? 1 : 0)
                .rotation3DEffect(
                    .degrees(isShowingAnswer ? 0 : 180),
                    axis: (x: 0, y: 1, z: 0)
                )
            }
            .animation(.easeInOut(duration: 0.45), value: isShowingAnswer)
        }
        .buttonStyle(.plain)
    }
}

private struct FlashcardFaceView: View {
    let emoji: String
    let text: String
    let footerText: String

    var body: some View {
        VStack(spacing: 0) {
            Text(emoji)
                .font(.largeTitle)
                .padding(.top, 56)

            Spacer()

            Text(text)
                .font(.title2)
                .bold()
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)

            Spacer()

            Text(footerText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, minHeight: 520, maxHeight: .infinity)
        .background(.white)
        .clipShape(.rect(cornerRadius: 32))
        .shadow(color: .black.opacity(0.06), radius: 20, y: 6)
    }
}

private struct FlashcardsPageIndicator: View {
    let pageCount: Int
    let currentIndex: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<pageCount, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? .black : .black.opacity(0.12))
                    .frame(width: 10, height: 10)
            }
        }
    }
}
