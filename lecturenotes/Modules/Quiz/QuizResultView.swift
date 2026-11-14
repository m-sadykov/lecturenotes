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

private struct QuizMistakeRow: View {
    let mistake: QuizMistake

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(mistake.question)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

            QuizMistakeAnswerLine(
                title: "Your answer",
                answer: mistake.selectedAnswer,
                systemImage: "xmark.circle.fill",
                tint: .red
            )

            QuizMistakeAnswerLine(
                title: "Correct answer",
                answer: mistake.correctAnswer,
                systemImage: "checkmark.circle.fill",
                tint: .green
            )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface)
        .clipShape(.rect(cornerRadius: 18))
    }
}

private struct QuizMistakeAnswerLine: View {
    let title: LocalizedStringResource
    let answer: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(answer)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
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
                question: "Who is the host introducing the course on C.S. Lewis?",
                selectedAnswer: "Timothy Shutt",
                correctAnswer: "Jack Garrett"
            ),
        ],
        showsNewSet: true
    ) {}
    .background(AppColor.canvas)
}
