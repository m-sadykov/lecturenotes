import SwiftUI

struct QuizResultView: View {
    let score: Int
    let total: Int
    let tier: QuizResultTier
    var mistakes: [QuizMistake] = []
    /// Whether to offer a freshly generated quiz.
    var showsNewSet = false
    var onNewSet: () -> Void = {}
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Text(tier.headline)
                    .font(.largeTitle)
                    .bold()
                    .multilineTextAlignment(.center)
                    .padding(.top, 40)

                HStack(spacing: 18) {
                    QuizResultScoreCard(value: score, title: "Correct")
                    QuizResultScoreCard(value: wrongCount, title: "Wrong")
                }

                if !mistakes.isEmpty {
                    QuizMistakesSection(mistakes: mistakes)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            QuizResultActions(showsNewSet: showsNewSet, onNewSet: onNewSet, onDone: onDone)
        }
    }

    private var wrongCount: Int {
        max(total - score, 0)
    }
}

private struct QuizResultScoreCard: View {
    let value: Int
    let title: LocalizedStringResource

    var body: some View {
        VStack(spacing: 8) {
            Text(value, format: .number)
                .font(.largeTitle)
                .bold()
            Text(title)
                .font(.title3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(AppColor.surface)
        .clipShape(.rect(cornerRadius: 22))
    }
}

/// The questions answered wrongly, each with the chosen and the correct answer.
private struct QuizMistakesSection: View {
    let mistakes: [QuizMistake]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Review your mistakes")
                .font(.title3)
                .bold()

            ForEach(mistakes) { mistake in
                QuizMistakeRow(mistake: mistake)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A wrong answer shown the way the question looked in the quiz: the numbered badge,
/// the question, the chosen option in pink and the right one outlined in mint.
private struct QuizMistakeRow: View {
    let mistake: QuizMistake

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Question \(mistake.number)")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppColor.fillSubtle)
                .clipShape(.rect(cornerRadius: 8))

            Text(mistake.question)
                .font(.title3)
                .bold()
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 20)

            VStack(spacing: 12) {
                QuizOptionLabel(text: mistake.selectedAnswer, state: .incorrect) {
                    Image(systemName: "xmark")
                        .font(.subheadline.bold())
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("Your answer"))
                .accessibilityValue(Text(mistake.selectedAnswer))

                QuizOptionLabel(text: mistake.correctAnswer, state: .revealedCorrect) {
                    Image(systemName: "checkmark")
                        .font(.subheadline.bold())
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("Correct answer"))
                .accessibilityValue(Text(mistake.correctAnswer))
            }
            .padding(.top, 20)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface)
        .clipShape(.rect(cornerRadius: 22))
    }
}

/// "New Set" and "Finish", pinned above the home indicator while the results scroll.
private struct QuizResultActions: View {
    let showsNewSet: Bool
    let onNewSet: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if showsNewSet {
                Button("New Set", systemImage: "arrow.clockwise", action: onNewSet)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: 320)
                    .padding(.vertical, 18)
                    .background(AppColor.surface, in: .capsule)
                    .buttonStyle(.plain)
            }

            Button("Finish", action: onDone)
                .font(.headline)
                .foregroundStyle(AppColor.onInk)
                .frame(maxWidth: 320)
                .padding(.vertical, 18)
                .background(AppColor.ink, in: .capsule)
                .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(AppColor.canvas)
    }
}

#Preview {
    QuizResultView(
        score: 3,
        total: 12,
        tier: .keepPracticing,
        mistakes: [
            QuizMistake(
                id: UUID(),
                number: 1,
                question: "Who is the host introducing the course on C.S. Lewis?",
                selectedAnswer: "Timothy Shutt",
                correctAnswer: "Jack Garrett"
            ),
        ],
        showsNewSet: true
    ) {}
    .background(AppColor.canvas)
}
