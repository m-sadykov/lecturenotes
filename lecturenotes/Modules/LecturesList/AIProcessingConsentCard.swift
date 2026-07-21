import SwiftUI

struct AIProcessingConsentCard: View {
    let onCancel: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 14) {
                Text("AI Data Processing")
                    .font(.title3)
                    .bold()

                Text(
                    "To create transcripts, summaries, flashcards, and quizzes, the app sends your imported text, PDF, or audio recording to Firebase and OpenAI for processing."
                )
                .font(.body)
                .foregroundStyle(.secondary)

                Text(
                    "By tapping Continue, you agree to share this content with these services so your lecture can be processed."
                )
                .font(.body)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                Button("Cancel", action: onCancel)
                    .buttonStyle(
                        AIConsentButtonStyle(
                            background: AppColor.fillSubtle,
                            usesPrimaryForeground: true
                        )
                    )

                Button("Continue", action: onContinue)
                    .buttonStyle(
                        AIConsentButtonStyle(
                            background: Color(red: 0.86, green: 0.25, blue: 0.24),
                            usesPrimaryForeground: false
                        )
                    )
            }
        }
        .padding(24)
        .frame(maxWidth: 520, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(AppColor.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(AppColor.hairline, lineWidth: 1)
                }
                .shadow(color: AppColor.shadow, radius: 24, y: 12)
        )
    }
}

private struct AIConsentButtonStyle: ButtonStyle {
    let background: Color
    let usesPrimaryForeground: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(usesPrimaryForeground ? Color.primary : AppColor.onInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(background.opacity(configuration.isPressed ? 0.82 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        AppColor.overlayScrim
            .ignoresSafeArea()

        AIProcessingConsentCard(onCancel: {}, onContinue: {})
            .padding(20)
    }
}
