import SwiftUI
import UIKit

struct LectureDetailView: View {
    let lecture: Lecture
    let repository: LectureRepository
    let processingService: FirebaseLectureProcessingService?
    let onLectureUpdated: (Lecture) -> Void
    @State private var editableLecture: Lecture
    @State private var playerViewModel: LecturePlayerViewModel?
    @State private var processingViewModel: LectureProcessingViewModel?
    @State private var selectedSection: LectureDetailSection = .summary
    @State private var activeDestination: LectureDetailDestination?
    @State private var isRenameAlertPresented = false
    @State private var isDeleteAlertPresented = false
    @State private var draftTitle = ""
    @State private var toastMessage: String?
    @State private var processingErrorFeedbackToken = 0
    @State private var processingSuccessFeedbackToken = 0
    @Environment(\.dismiss) private var dismiss

    init(
        lecture: Lecture,
        repository: LectureRepository,
        processingService: FirebaseLectureProcessingService? = nil,
        onLectureUpdated: @escaping (Lecture) -> Void = { _ in }
    ) {
        self.lecture = lecture
        self.repository = repository
        self.processingService = processingService
        self.onLectureUpdated = onLectureUpdated
        _editableLecture = State(initialValue: lecture)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 18) {
                if let playerViewModel {
                    LectureAudioPlayerView(lecture: editableLecture, viewModel: playerViewModel)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            ZStack {
                if shouldShowProcessing, let processingLecture = processingLecture {
                    ProcessingView(
                        lecture: processingLecture,
                        isRetrying: processingViewModel?.isRetrying == true,
                        onRetry: processingLecture.status == .failed ? {
                            Task {
                                await processingViewModel?.retryProcessing()
                            }
                        } : nil
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if !shouldShowProcessing {
                    VStack(spacing: 0) {
                        LectureDetailSectionChipsView(
                            selectedSection: $selectedSection,
                            onSelectSection: { section in
                                switch section {
                                case .flashcards:
                                    activeDestination = .flashcards
                                case .quiz:
                                    activeDestination = .quiz
                                default:
                                    selectedSection = section
                                }
                            }
                        )
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                        LectureDetailSectionContentView(
                            lecture: editableLecture,
                            selectedSection: selectedSection
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .background(Color(.systemGray6))
        .task {
            guard playerViewModel == nil else {
                return
            }

            playerViewModel = LecturePlayerViewModel(
                audioURL: lecture.audioURL,
                fallbackDuration: lecture.duration
            )
        }
        .task {
            guard processingViewModel == nil, let processingService else {
                return
            }

            let viewModel = LectureProcessingViewModel(
                lecture: editableLecture,
                repository: repository,
                processingService: processingService,
                onLectureUpdated: { updatedLecture in
                    editableLecture = updatedLecture
                    onLectureUpdated(updatedLecture)
                }
            )
            processingViewModel = viewModel
            await viewModel.start()
        }
        .onDisappear {
            playerViewModel?.cleanup()
            processingViewModel?.stop()
        }
        .onChange(of: processingLecture?.status) { oldValue, newValue in
            guard oldValue != .failed, newValue == .failed else {
                if oldValue != .ready, newValue == .ready {
                    processingSuccessFeedbackToken += 1
                }
                return
            }

            processingErrorFeedbackToken += 1
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Copy", systemImage: "doc.on.doc") {
                    copyActiveSectionText()
                }
                .disabled(copyableText == nil)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit Title", systemImage: "pencil") {
                        draftTitle = editableLecture.title
                        isRenameAlertPresented = true
                    }

                    Button("Delete Recording", systemImage: "trash", role: .destructive) {
                        isDeleteAlertPresented = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.primary)
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: processingErrorFeedbackToken)
        .sensoryFeedback(.success, trigger: processingSuccessFeedbackToken)
        .overlay(alignment: .top) {
            if let toastMessage {
                LectureDetailToastView(message: toastMessage)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .fullScreenCover(item: $activeDestination) { destination in
            NavigationStack {
            switch destination {
            case .flashcards:
                FlashcardsPracticeView(viewModel: FlashcardsPracticeViewModel(cards: editableLecture.flashcards))
            case .quiz:
                QuizView(viewModel: QuizViewModel(questions: editableLecture.quiz))
            }
            }
        }
        .alert("Edit Title", isPresented: $isRenameAlertPresented) {
            TextField("Recording title", text: $draftTitle)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmedTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedTitle.isEmpty else {
                    return
                }
                editableLecture.title = trimmedTitle
                persistLectureChanges()
            }
        } message: {
            Text("Update the recording title.")
        }
        .alert("Delete Recording?", isPresented: $isDeleteAlertPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .animation(.easeInOut(duration: 0.2), value: toastMessage != nil)
        .animation(.easeInOut(duration: 0.32), value: shouldShowProcessing)
    }

    private var copyableText: String? {
        switch selectedSection {
        case .summary:
            let text = editableLecture.summaryLong.isEmpty ? editableLecture.summaryShort : editableLecture.summaryLong
            return text.isEmpty ? nil : text
        case .transcript:
            return editableLecture.transcript.isEmpty ? nil : editableLecture.transcript
        case .flashcards, .quiz:
            return nil
        }
    }

    private var processingLecture: Lecture? {
        processingViewModel?.lecture ?? (editableLecture.status == .ready ? nil : editableLecture)
    }

    private var shouldShowProcessing: Bool {
        processingViewModel?.shouldShowProcessing ?? (editableLecture.status != .ready)
    }

    private func copyActiveSectionText() {
        guard let copyableText else {
            return
        }

        UIPasteboard.general.string = copyableText
        let sectionName = selectedSection == .summary ? "Summary" : "Transcript"
        showToast("\(sectionName) copied.")
    }

    private func showToast(_ message: String) {
        toastMessage = message

        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                guard toastMessage == message else {
                    return
                }
                toastMessage = nil
            }
        }
    }

    private func persistLectureChanges() {
        let lectureToSave = editableLecture
        onLectureUpdated(lectureToSave)

        Task {
            try? await repository.saveLecture(lectureToSave)
        }
    }
}

#Preview {
    NavigationStack {
        if let lecture = previewLecture {
            LectureDetailView(
                lecture: lecture,
                repository: MockLectureRepository()
            )
        }
    }
}

#Preview("Processing") {
    NavigationStack {
        LectureDetailView(
            lecture: processingPreviewLecture,
            repository: MockLectureRepository()
        )
    }
}

#Preview("Processing Failed") {
    NavigationStack {
        LectureDetailView(
            lecture: failedProcessingPreviewLecture,
            repository: MockLectureRepository()
        )
    }
}

private let previewLecture: Lecture? = {
    guard var lecture = MockLectures.makeLectures().first else {
        return nil
    }

    lecture.audioURL = nil
    return lecture
}()

private let processingPreviewLecture = Lecture(
    title: "New Recording",
    course: "Biology 101",
    audioURL: nil,
    createdAt: Date(timeIntervalSinceReferenceDate: 794_855_467),
    duration: .seconds(3),
    status: .transcribing,
    transcript: "",
    summaryShort: "",
    summaryLong: "",
    flashcards: [],
    quiz: []
)

private let failedProcessingPreviewLecture = Lecture(
    title: "New Recording",
    course: "Biology 101",
    audioURL: nil,
    createdAt: Date(timeIntervalSinceReferenceDate: 794_855_467),
    duration: .seconds(3),
    status: .failed,
    transcript: "",
    summaryShort: "",
    summaryLong: "",
    flashcards: [],
    quiz: [],
    processingErrorMessage: "No speech detected. Try speaking louder or recording for longer."
)

private enum LectureDetailSection: String, CaseIterable, Identifiable {
    case summary = "Summary"
    case transcript = "Transcript"
    case flashcards = "Flashcards"
    case quiz = "Quiz"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .summary:
            "📝"
        case .transcript:
            "📄"
        case .flashcards:
            "🔄"
        case .quiz:
            "⁉️"
        }
    }
}

private enum LectureDetailDestination: Identifiable {
    case flashcards
    case quiz

    var id: String {
        switch self {
        case .flashcards:
            "flashcards"
        case .quiz:
            "quiz"
        }
    }
}

private struct LectureDetailSectionChipsView: View {
    @Binding var selectedSection: LectureDetailSection
    let onSelectSection: (LectureDetailSection) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(LectureDetailSection.allCases) { section in
                    LectureDetailSectionChip(
                        title: section.rawValue,
                        emoji: section.emoji,
                        isSelected: selectedSection == section
                    ) {
                        onSelectSection(section)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
    }
}

private struct LectureDetailSectionChip: View {
    let title: String
    let emoji: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Text(emoji)
                    .font(.title2)

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            .frame(width: 108, height: 88)
            .background(.black.opacity(0.05))
            .clipShape(.rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.black.opacity(0.10) : Color.black.opacity(0.03), lineWidth: 1)
            }
            .shadow(color: .black.opacity(isSelected ? 0.07 : 0.04), radius: isSelected ? 14 : 12, y: 4)
        }
        .buttonStyle(.plain)
    }
}

private struct LectureDetailSectionContentView: View {
    let lecture: Lecture
    let selectedSection: LectureDetailSection

    var body: some View {
        Group {
            switch selectedSection {
            case .summary:
                SummarySectionView(lecture: lecture)
            case .transcript:
                TranscriptSectionView(lecture: lecture)
            case .flashcards:
                SummarySectionView(lecture: lecture)
            case .quiz:
                SummarySectionView(lecture: lecture)
            }
        }
    }
}

private struct LectureDetailToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.black.opacity(0.88))
            .clipShape(.rect(cornerRadius: 14))
            .shadow(radius: 10, y: 4)
    }
}
