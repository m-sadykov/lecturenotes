import SwiftUI

struct QuizResultView: View {
    let score: Int
    let total: Int
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Well done!")
                .font(.largeTitle)
                .bold()

            HStack(spacing: 18) {
                resultCard(value: score, title: "Correct")
                resultCard(value: wrongCount, title: "Wrong")
            }
            .padding(.top, 48)

            Spacer()

            Button("Finish", action: onDone)
                .font(.headline)
                .foregroundStyle(AppColor.onInk)
                .frame(maxWidth: 320)
                .padding(.vertical, 18)
                .background(AppColor.ink, in: .capsule)
                .buttonStyle(.plain)
                .padding(.bottom, 44)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    private var wrongCount: Int {
        max(total - score, 0)
    }

    private func resultCard(value: Int, title: LocalizedStringResource) -> some View {
        VStack(spacing: 8) {
            Text("\(value)")
                .font(.largeTitle)
                .bold()
            Text(title)
                .font(.title3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(AppColor.surface)
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(AppColor.hairline, lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: 22))
    }
}
