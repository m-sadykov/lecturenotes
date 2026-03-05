import SwiftUI

struct QuizView: View {
    @State var viewModel: QuizViewModel

    var body: some View {
        VStack {
            Text("Progress: \(viewModel.progressText)")
                .foregroundStyle(.secondary)

            if viewModel.isFinished {
                QuizResultView(score: viewModel.score, total: viewModel.questions.count)
            } else if let question = viewModel.currentQuestion {
                VStack(alignment: .leading) {
                    Text(question.question)
                        .bold()

                    ForEach(question.options.enumerated(), id: \.offset) { index, option in
                        QuizOptionButton(text: option, isSelected: viewModel.selectedIndex == index) {
                            viewModel.select(optionIndex: index)
                        }
                    }

                    Button("Submit", systemImage: "arrow.right.circle") {
                        viewModel.submitAndMoveNext()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.selectedIndex == nil)
                }
            } else {
                Text("No quiz available")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Quiz")
    }
}

#Preview {
    NavigationStack {
        QuizView(viewModel: QuizViewModel(questions: MockLectures.makeLectures()[0].quiz))
    }
}
