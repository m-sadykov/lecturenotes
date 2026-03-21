import Observation
import SwiftUI
import UIKit

enum LectureDetailSection: String, CaseIterable, Identifiable {
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

enum LectureDetailDestination: Identifiable {
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

@MainActor
@Observable
final class LectureDetailViewModel {
    var lecture: Lecture
    var playerViewModel: LecturePlayerViewModel?
    var processingViewModel: LectureProcessingViewModel?
    var selectedSection: LectureDetailSection = .summary
    var activeDestination: LectureDetailDestination?
    var isRenameAlertPresented = false
    var isDeleteAlertPresented = false
    var isSavingTitle = false
    var draftTitle = ""
    var toastMessage: String?
    var processingErrorFeedbackToken = 0
    var processingSuccessFeedbackToken = 0

    @ObservationIgnored private let repository: LectureRepository
    @ObservationIgnored private let processingService: FirebaseLectureProcessingService?
    @ObservationIgnored private let onLectureUpdated: (Lecture) -> Void
    @ObservationIgnored private let onLectureDeleted: (Lecture.ID) async -> Bool
    @ObservationIgnored private var repositoryObservationTask: Task<Void, Never>?

    init(
        lecture: Lecture,
        repository: LectureRepository,
        processingService: FirebaseLectureProcessingService? = nil,
        onLectureUpdated: @escaping (Lecture) -> Void = { _ in },
        onLectureDeleted: @escaping (Lecture.ID) async -> Bool = { _ in true }
    ) {
        self.lecture = lecture
        self.repository = repository
        self.processingService = processingService
        self.onLectureUpdated = onLectureUpdated
        self.onLectureDeleted = onLectureDeleted
    }

    var copyableText: String? {
        switch selectedSection {
        case .summary:
            let text = lecture.summaryLong.isEmpty ? lecture.summaryShort : lecture.summaryLong
            return text.isEmpty ? nil : text
        case .transcript:
            return lecture.transcript.isEmpty ? nil : lecture.transcript
        case .flashcards, .quiz:
            return nil
        }
    }

    var processingLecture: Lecture? {
        processingViewModel?.lecture ?? (lecture.status == .ready ? nil : lecture)
    }

    var shouldShowProcessing: Bool {
        processingViewModel?.shouldShowProcessing ?? (lecture.status != .ready)
    }

    func prepareAudioPlayerIfNeeded() {
        guard playerViewModel == nil, lecture.sourceType == .audio else {
            return
        }

        playerViewModel = LecturePlayerViewModel(
            audioURL: lecture.audioURL,
            fallbackDuration: lecture.duration
        )
    }

    func startProcessingIfNeeded() async {
        guard processingViewModel == nil, let processingService else {
            return
        }

        let viewModel = LectureProcessingViewModel(
            lecture: lecture,
            repository: repository,
            processingService: processingService,
            onLectureUpdated: { [weak self] updatedLecture in
                guard let self else {
                    return
                }

                lecture = updatedLecture
                onLectureUpdated(updatedLecture)
            }
        )
        processingViewModel = viewModel
        await viewModel.start()
    }

    func startObservingLecture() async {
        guard repositoryObservationTask == nil else {
            return
        }

        await repository.start()
        await reloadLectureFromRepository()

        repositoryObservationTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            for await _ in repository.observeChanges() {
                await reloadLectureFromRepository()
            }
        }
    }

    func cleanup() {
        repositoryObservationTask?.cancel()
        repositoryObservationTask = nil
        playerViewModel?.cleanup()
        processingViewModel?.stop()
    }

    func handleProcessingStatusChange(oldValue: LectureStatus?, newValue: LectureStatus?) {
        guard oldValue != .failed, newValue == .failed else {
            if oldValue != .ready, newValue == .ready {
                processingSuccessFeedbackToken += 1
            }
            return
        }

        processingErrorFeedbackToken += 1
    }

    func selectSection(_ section: LectureDetailSection) {
        switch section {
        case .flashcards:
            activeDestination = .flashcards
        case .quiz:
            activeDestination = .quiz
        case .summary, .transcript:
            selectedSection = section
        }
    }

    func retryProcessing() async {
        await processingViewModel?.retryProcessing()
    }

    func presentRename() {
        draftTitle = lecture.title
        isRenameAlertPresented = true
    }

    func saveRenamedLecture() {
        let trimmedTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !isSavingTitle else {
            return
        }

        guard lecture.title != trimmedTitle else {
            return
        }

        let previousLecture = lecture
        var renamedLecture = lecture
        renamedLecture.title = trimmedTitle

        lecture = renamedLecture
        onLectureUpdated(renamedLecture)
        isSavingTitle = true

        Task {
            do {
                try await repository.saveLecture(renamedLecture)
                showToast("Title updated.")
            } catch {
                lecture = previousLecture
                onLectureUpdated(previousLecture)
                try? await repository.saveLecture(previousLecture)
                showToast("Unable to update title right now.")
            }

            isSavingTitle = false
        }
    }

    func copyActiveSectionText() {
        guard let copyableText else {
            return
        }

        UIPasteboard.general.string = copyableText
        let sectionName = selectedSection == .summary ? "Summary" : "Transcript"
        showToast("\(sectionName) copied.")
    }

    func requestDelete() {
        isDeleteAlertPresented = true
    }

    func confirmDelete() async -> Bool {
        let wasDeleted = await onLectureDeleted(lecture.id)
        if !wasDeleted {
            showToast("Unable to delete lecture right now.")
        }
        return wasDeleted
    }

    func showToast(_ message: String) {
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

    private func reloadLectureFromRepository() async {
        guard let updatedLecture = await repository.fetchLecture(id: lecture.id) else {
            return
        }

        lecture = updatedLecture
        processingViewModel?.applyCachedLecture(updatedLecture)
        onLectureUpdated(updatedLecture)
    }
}
