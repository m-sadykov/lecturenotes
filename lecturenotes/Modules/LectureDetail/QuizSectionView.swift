import SwiftUI

struct QuizSectionView: View {
    let lecture: Lecture

    var body: some View {
        List {
            Section {
                NavigationLink {
                    QuizView(viewModel: QuizViewModel(questions: lecture.quiz))
                } label: {
                    Label("Start Quiz", systemImage: "play.circle")
                }
            }

            if lecture.quiz.isEmpty {
                Text("Quiz is not available yet.")
                    .foregroundStyle(.secondary)
            } else {
                Text("Questions: \(lecture.quiz.count)")
            }
        }
    }
}
