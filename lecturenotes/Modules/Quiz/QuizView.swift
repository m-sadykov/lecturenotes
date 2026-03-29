import SwiftUI

struct QuizView: View {
    @State var viewModel: QuizViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackTrigger = 0
    @State private var isCloseAlertPresented = false

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()

            if !viewModel.hasQuestions {
                Text("No quiz available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.isFinished {
                QuizResultView(score: viewModel.correctCount, total: viewModel.questions.count) {
                    dismiss()
                }
            } else {
                VStack(spacing: 0) {
                    QuizProgressHeaderView(
                        progressValue: viewModel.progressValue,
                        progressText: viewModel.progressText
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 22)

                    TabView(selection: $viewModel.currentIndex) {
                        ForEach(viewModel.questions.indices, id: \.self) { index in
                            let question = viewModel.questions[index]
                            QuizQuestionCardView(
                                question: question,
                                questionNumber: index + 1,
                                selectedIndex: viewModel.currentIndex == index ? viewModel.selectedIndex : nil,
                                lastAnswerWasCorrect: viewModel.currentIndex == index ? viewModel.lastAnswerWasCorrect : nil,
                                onSelectOption: { optionIndex in
                                    handleOptionSelection(optionIndex)
                                }
                            )
                            .padding(.horizontal, 24)
                            .padding(.bottom, 32)
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .onChange(of: viewModel.currentIndex, initial: false) { _, newIndex in
                        viewModel.showQuestion(at: newIndex)
                    }
                }
            }
        }
        .navigationTitle("Quiz")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .light), trigger: feedbackTrigger)
        .interactiveDismissDisabled(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close", systemImage: "xmark") {
                    if viewModel.questionsAnsweredCount > 0 {
                        isCloseAlertPresented = true
                    } else {
                        dismiss()
                    }
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(.primary)
            }
        }
        .alert("Close Quiz?", isPresented: $isCloseAlertPresented) {
            Button("Keep Going", role: .cancel) {}
            Button("Close", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("Your current quiz progress will be reset.")
        }
    }
}

#Preview {
    NavigationStack {
        QuizView(viewModel: QuizViewModel(questions: MockLectures.makeLectures()[0].quiz))
    }
}

private extension QuizView {
    func handleOptionSelection(_ optionIndex: Int) {
        guard !viewModel.hasAnsweredCurrentQuestion else {
            return
        }

        feedbackTrigger += 1
        viewModel.select(optionIndex: optionIndex)

        Task {
            try? await Task.sleep(for: .milliseconds(850))
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.moveToNextQuestion()
                }
            }
        }
    }
}

private struct QuizProgressHeaderView: View {
    let progressValue: Double
    let progressText: String

    var body: some View {
        HStack(spacing: 16) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.black.opacity(0.06))
                        .frame(height: 10)

                    Capsule()
                        .fill(.black.opacity(0.85))
                        .frame(width: max(geometry.size.width * progressValue, 10), height: 10)
                }
            }
            .frame(height: 10)

            Text(progressText)
                .font(.title3.monospacedDigit())
                .foregroundStyle(.primary)
        }
    }
}

private struct QuizQuestionCardView: View {
    let question: QuizQuestion
    let questionNumber: Int
    let selectedIndex: Int?
    let lastAnswerWasCorrect: Bool?
    let onSelectOption: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Question \(questionNumber)")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.03))
                    .clipShape(.rect(cornerRadius: 8))

                Spacer()

                if let lastAnswerWasCorrect {
                    if lastAnswerWasCorrect {
                        Text("🎉 Correct")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    } else {
                        Text("🙅 Wrong")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                }
            }

            Text(question.question)
                .font(.title2)
                .bold()
                .padding(.top, 28)

            VStack(spacing: 16) {
                ForEach(question.options.indices, id: \.self) { index in
                    let option = question.options[index]
                    QuizOptionButton(
                        text: option,
                        state: optionState(for: index)
                    ) {
                        onSelectOption(index)
                    }
                }
            }
            .padding(.top, 28)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.white)
        .clipShape(.rect(cornerRadius: 30))
        .shadow(color: .black.opacity(0.06), radius: 18, y: 6)
    }

    private func optionState(for index: Int) -> QuizOptionState {
        guard let selectedIndex else {
            return .idle
        }

        if index == question.correctIndex {
            return index == selectedIndex ? .correct : .revealedCorrect
        }

        if index == selectedIndex {
            return .incorrect
        }

        return .idle
    }
}
