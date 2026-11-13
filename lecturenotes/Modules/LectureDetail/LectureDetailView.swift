import SwiftUI

struct LectureDetailView: View {
    @State private var viewModel: LectureDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isActionsPopoverPresented = false

    init(
        lecture: Lecture,
        repository: LectureRepository,
        processingService: FirebaseLectureProcessingService? = nil,
        analyticsService: AppAnalyticsService? = nil,
        crashReportingService: CrashReportingService? = nil,
        onLectureUpdated: @escaping (Lecture) -> Void = { _ in },
        onLectureDeleted: @escaping (Lecture.ID) async -> String? = { _ in nil }
    ) {
        _viewModel = State(
            initialValue: LectureDetailViewModel(
                lecture: lecture,
                repository: repository,
                processingService: processingService,
                analyticsService: analyticsService,
                crashReportingService: crashReportingService,
                onLectureUpdated: onLectureUpdated,
                onLectureDeleted: onLectureDeleted
            )
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        Group {
            if viewModel.shouldShowProcessing, let processingLecture = viewModel.processingLecture {
                VStack(spacing: 16) {
                    LectureDetailTopContentView(viewModel: viewModel, isProcessing: true)
                        .padding(.horizontal)
                        .padding(.top, 8)

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
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            LectureDetailTopContentView(viewModel: viewModel, isProcessing: false)

                            LectureDetailActionsGridView(
                                lecture: viewModel.lecture,
                                onOpen: viewModel.open
                            )

                            LectureSummarySectionView(
                                summaryText: viewModel.summaryText,
                                briefText: viewModel.summaryBriefText,
                                onCopy: { viewModel.copy(.summary) },
                                onSelectSection: { item in
                                    withAnimation {
                                        scrollProxy.scrollTo(MarkdownOutline.anchor(for: item.blockIndex), anchor: .top)
                                    }
                                }
                            )
                            .padding(.top, 8)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .background(AppColor.canvas)
        .task {
            viewModel.configureCrashContext()
        }
        .task {
            viewModel.syncAudioPlayer()
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
        .circleBackButton()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ToolbarCircleButton("Actions", systemImage: "ellipsis") {
                    isActionsPopoverPresented = true
                }
                .popover(isPresented: $isActionsPopoverPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                    LectureDetailActionsSheet(
                        onAddToFolder: {
                            viewModel.presentFolderPicker()
                        },
                        onRemoveFromFolder: viewModel.lecture.folderID == nil ? nil : {
                            viewModel.removeLectureFromFolder()
                        },
                        onEditTitle: {
                            viewModel.presentRename()
                        },
                        onDelete: {
                            viewModel.requestDelete()
                        }
                    )
                    .presentationCompactAdaptation(.popover)
                }
            }
            .hiddenSharedBackground()
        }
        .navigationDestination(item: $viewModel.activeRoute) { route in
            switch route {
            case .transcript:
                LectureTranscriptScreen(
                    transcript: viewModel.lecture.transcript,
                    onCopy: { viewModel.copy(.transcript) }
                )
            case .keyPoints:
                LectureKeyPointsScreen(
                    keyPoints: viewModel.lecture.keyPoints,
                    onCopy: { viewModel.copy(.keyPoints) }
                )
            }
        }
        .sheet(
            isPresented: $viewModel.isFolderPickerPresented,
            onDismiss: {
                viewModel.isFolderPickerPresented = false
            }
        ) {
            FolderSelectionSheet(
                lecture: viewModel.lecture,
                folders: viewModel.folders,
                selectedFolderID: viewModel.lecture.folderID,
                onCreateFolder: { folderName in
                    viewModel.createFolder(named: folderName)
                },
                onSelectFolder: { folderID in
                    viewModel.addLectureToFolder(folderID)
                },
                onClose: {
                    viewModel.isFolderPickerPresented = false
                }
            )
            .presentationDetents([.fraction(0.52), .large])
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
                    FlashcardsPracticeView(
                        viewModel: FlashcardsPracticeViewModel(
                            cards: viewModel.lecture.flashcards,
                            analyticsService: viewModel.analytics,
                            analyticsContext: .init(lecture: viewModel.lecture)
                        )
                    )
                case .quiz:
                    QuizView(
                        viewModel: QuizViewModel(
                            questions: viewModel.lecture.quiz,
                            analyticsService: viewModel.analytics,
                            analyticsContext: .init(lecture: viewModel.lecture)
                        )
                    )
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
        .alert("Error", isPresented: $viewModel.isErrorAlertPresented) {
            Button("OK") {
                viewModel.dismissErrorAlert()
            }
        } message: {
            Text(viewModel.errorAlertMessage)
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

private struct LectureDetailToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .foregroundStyle(AppColor.onInk)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppColor.ink.opacity(0.88))
            .clipShape(.rect(cornerRadius: 14))
            .shadow(color: AppColor.shadow, radius: 10, y: 4)
    }
}

/// Header and, for audio lectures, the player card. While the lecture is still processing
/// only the title and metadata are shown: the audio is not uploaded yet and the lecture
/// is not ready to be organized.
private struct LectureDetailTopContentView: View {
    let viewModel: LectureDetailViewModel
    let isProcessing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LectureDetailHeaderView(
                lecture: viewModel.lecture,
                folderName: viewModel.folderName,
                showsFolderChip: !isProcessing,
                onFolderTap: viewModel.presentFolderPicker
            )

            if !isProcessing, let playerViewModel = viewModel.playerViewModel {
                LectureAudioPlayerView(lecture: viewModel.lecture, viewModel: playerViewModel)
            }
        }
    }
}
