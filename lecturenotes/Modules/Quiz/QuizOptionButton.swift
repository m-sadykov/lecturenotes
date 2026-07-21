import SwiftUI

struct QuizOptionButton: View {
    let text: String
    let state: QuizOptionState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top) {
                Text(text)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .background(backgroundStyle)
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(borderColor, lineWidth: 1.5)
            }
            .clipShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(state != .idle)
    }

    private var backgroundStyle: Color {
        switch state {
        case .idle, .revealedCorrect:
            Color.primary.opacity(0.14)
        case .correct:
            Color(red: 0.46, green: 0.88, blue: 0.76)
        case .incorrect:
            Color(red: 0.94, green: 0.65, blue: 0.67)
        }
    }

    private var borderColor: Color {
        switch state {
        case .idle:
            Color.primary.opacity(0.22)
        case .correct, .revealedCorrect:
            Color(red: 0.22, green: 0.83, blue: 0.67)
        case .incorrect:
            Color(red: 0.90, green: 0.45, blue: 0.49)
        }
    }
}

enum QuizOptionState {
    case idle
    case correct
    case incorrect
    case revealedCorrect
}
