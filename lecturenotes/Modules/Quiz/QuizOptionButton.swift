import SwiftUI

struct QuizOptionButton: View {
    let text: String
    let state: QuizOptionState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            QuizOptionLabel(text: text, state: state)
        }
        .buttonStyle(.plain)
        .disabled(state != .idle)
    }
}

/// An answer option's pill: plain while unanswered, pink for a wrong pick, mint for the
/// right one. Shared by the quiz and the mistakes review on the results screen.
struct QuizOptionLabel<Accessory: View>: View {
    let text: String
    let state: QuizOptionState
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(text)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            accessory
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .background(state.fill)
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(state.border, lineWidth: 1.5)
        }
        .clipShape(.rect(cornerRadius: 18))
    }
}

extension QuizOptionLabel where Accessory == EmptyView {
    init(text: String, state: QuizOptionState) {
        self.init(text: text, state: state) { EmptyView() }
    }
}

enum QuizOptionState {
    case idle
    case correct
    case incorrect
    case revealedCorrect
}

extension QuizOptionState {
    var fill: Color {
        switch self {
        case .idle, .revealedCorrect:
            // Same fill as the "Question N" badge above, so the card reads as one surface.
            AppColor.fillSubtle
        case .correct:
            Color(red: 0.46, green: 0.88, blue: 0.76)
        case .incorrect:
            Color(red: 0.94, green: 0.65, blue: 0.67)
        }
    }

    var border: Color {
        switch self {
        case .idle:
            .clear
        case .correct, .revealedCorrect:
            Color(red: 0.22, green: 0.83, blue: 0.67)
        case .incorrect:
            Color(red: 0.90, green: 0.45, blue: 0.49)
        }
    }
}
