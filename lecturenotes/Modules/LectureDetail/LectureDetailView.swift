import SwiftUI

struct LectureDetailView: View {
    @State private var viewModel: LectureDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        lecture: Lecture,
        repository: LectureRepository,
        processingService: FirebaseLectureProcessingService? = nil,
        onLectureUpdated: @escaping (Lecture) -> Void = { _ in },
        onLectureDeleted: @escaping (Lecture.ID) async -> Bool = { _ in true }
    ) {
        _viewModel = State(
            initialValue: LectureDetailViewModel(
                lecture: lecture,
                repository: repository,
                processingService: processingService,
                onLectureUpdated: onLectureUpdated,
                onLectureDeleted: onLectureDeleted
            )
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 0) {
            VStack(spacing: 18) {
                if viewModel.lecture.sourceType != .audio {
                    LectureTextHeaderView(lecture: viewModel.lecture)
                }

                if let playerViewModel = viewModel.playerViewModel {
                    LectureAudioPlayerView(lecture: viewModel.lecture, viewModel: playerViewModel)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            ZStack {
                if viewModel.shouldShowProcessing, let processingLecture = viewModel.processingLecture {
                    ProcessingView(
                        lecture: processingLecture,
                        isRetrying: viewModel.processingViewModel?.isRetrying == true,
                        onRetry: processingLecture.status == .failed ? {
                            Task {
                                await viewModel.retryProcessing()
                            }
                        } : nil
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if !viewModel.shouldShowProcessing {
                    VStack(spacing: 0) {
                        LectureDetailSectionChipsView(
                            selectedSection: $viewModel.selectedSection,
                            onSelectSection: viewModel.selectSection
                        )
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                        LectureDetailSectionContentView(
                            lecture: viewModel.lecture,
                            selectedSection: viewModel.selectedSection
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .background(Color(.systemGray6))
        .task {
            viewModel.prepareAudioPlayerIfNeeded()
        }
        .task {
            await viewModel.startObservingLecture()
        }
        .task {
            await viewModel.startProcessingIfNeeded()
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .onChange(of: viewModel.processingLecture?.status) { oldValue, newValue in
            viewModel.handleProcessingStatusChange(oldValue: oldValue, newValue: newValue)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Copy", systemImage: "doc.on.doc") {
                    viewModel.copyActiveSectionText()
                }
                .disabled(viewModel.copyableText == nil)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit Title", systemImage: "pencil") {
                        viewModel.presentRename()
                    }

                    Button("Delete Lecture", systemImage: "trash", role: .destructive) {
                        viewModel.requestDelete()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.primary)
                }
            }
        }
        .overlay(alignment: .top) {
            if let toastMessage = viewModel.toastMessage {
                LectureDetailToastView(message: toastMessage)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .fullScreenCover(item: $viewModel.activeDestination) { destination in
            NavigationStack {
                switch destination {
                case .flashcards:
                    FlashcardsPracticeView(viewModel: FlashcardsPracticeViewModel(cards: viewModel.lecture.flashcards))
                case .quiz:
                    QuizView(viewModel: QuizViewModel(questions: viewModel.lecture.quiz))
                }
            }
        }
        .alert("Edit Title", isPresented: $viewModel.isRenameAlertPresented) {
            TextField("Lecture title", text: $viewModel.draftTitle)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                viewModel.saveRenamedLecture()
            }
            .disabled(viewModel.draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSavingTitle)
        } message: {
            Text("Update the lecture title.")
        }
        .alert("Delete Lecture?", isPresented: $viewModel.isDeleteAlertPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    let wasDeleted = await viewModel.confirmDelete()
                    await MainActor.run {
                        if wasDeleted {
                            dismiss()
                        }
                    }
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.processingSuccessFeedbackToken)
        .animation(.easeInOut(duration: 0.2), value: viewModel.toastMessage != nil)
        .animation(.easeInOut(duration: 0.32), value: viewModel.shouldShowProcessing)
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
    sourceType: .audio,
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
    sourceType: .audio,
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

private struct LectureTextHeaderView: View {
    let lecture: Lecture

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(lecture.title)
                .font(.title)
                .bold()
                .lineLimit(2)

            Text(metadataText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
    }

    private var metadataText: String {
        "\(lecture.createdAt.formatted(.dateTime.month(.abbreviated).day().year())) · \(lecture.sourceType.title)"
    }
}
