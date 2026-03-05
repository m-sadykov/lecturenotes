import SwiftUI

struct QuizResultView: View {
    let score: Int
    let total: Int

    var body: some View {
        VStack {
            Text("Quiz Completed")
                .bold()
            Text("Score: \(score) / \(total)")
            Text(scoreText)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scoreText: String {
        guard total > 0 else { return "No questions" }
        let ratio = Double(score) / Double(total)
        if ratio >= 0.8 {
            return "Excellent"
        }
        if ratio >= 0.5 {
            return "Good progress"
        }
        return "Review notes and retry"
    }
}
