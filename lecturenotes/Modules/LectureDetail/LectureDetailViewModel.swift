import Observation
import SwiftUI
import UIKit

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
    var folders: [LectureFolder] = []
    var playerViewModel: LecturePlayerViewModel?
    var processingViewModel: LectureProcessingViewModel?
    var activeDestination: LectureDetailDestination?
    var activeRoute: LectureDetailRoute?
    var isFolderPickerPresented = false
    var isRenameAlertPresented = false
    var isDeleteAlertPresented = false
    var isErrorAlertPresented = false
    var isSavingTitle = false
    var isSavingFolder = false
    var draftTitle = ""
    var errorAlertMessage = ""
    var toastMessage: String?
    var processingErrorFeedbackToken = 0
    var processingSuccessFeedbackToken = 0

    @ObservationIgnored private let repository: LectureRepository
    @ObservationIgnored private let processingService: FirebaseLectureProcessingService?
    @ObservationIgnored private let analyticsService: AppAnalyticsService?
    @ObservationIgnored private let crashReportingService: CrashReportingService?
    @ObservationIgnored private let onLectureUpdated: (Lecture) -> Void
    @ObservationIgnored private let onLectureDeleted: (Lecture.ID) async -> String?
    @ObservationIgnored private var repositoryObservationTask: Task<Void, Never>?

    init(
        lecture: Lecture,
        repository: LectureRepository,
        processingService: FirebaseLectureProcessingService? = nil,
        analyticsService: AppAnalyticsService? = nil,
        crashReportingService: CrashReportingService? = nil,
        onLectureUpdated: @escaping (Lecture) -> Void = { _ in },
        onLectureDeleted: @escaping (Lecture.ID) async -> String? = { _ in nil }
    ) {
        self.lecture = lecture
        self.repository = repository
        self.processingService = processingService
        self.analyticsService = analyticsService
        self.crashReportingService = crashReportingService
        self.onLectureUpdated = onLectureUpdated
        self.onLectureDeleted = onLectureDeleted
    }

    /// The note shown on the detail screen: the Markdown study note when the backend
    /// produced one, otherwise the plain detailed summary, otherwise the short one.
    var summaryText: String {
        if !lecture.summaryNote.isEmpty {
            return lecture.summaryNote
        }
        return lecture.summaryLong.isEmpty ? lecture.summaryShort : lecture.summaryLong
    }

    /// The one- or two-sentence summary shown above the full note. Hidden when the
    /// full note is missing, because `summaryText` already falls back to it.
    var summaryBriefText: String? {
        let brief = lecture.summaryShort.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !brief.isEmpty, !lecture.summaryNote.isEmpty || !lecture.summaryLong.isEmpty else {
            return nil
        }
        return brief
    }

    var folderName: String? {
        guard let folderID = lecture.folderID else {
            return nil
        }
        return folders.first { $0.id == folderID }?.name
    }

    var processingLecture: Lecture? {
        processingViewModel?.lecture ?? (lecture.status == .ready ? nil : lecture)
    }

    var shouldShowProcessing: Bool {
        processingViewModel?.shouldShowProcessing ?? (lecture.status != .ready)
    }

    var analytics: AppAnalyticsService? {
        analyticsService
    }

    func configureCrashContext() {
        crashReportingService?.setCurrentScreen("lecture_detail")
        crashReportingService?.setCurrentFlow("lecture_detail")
        crashReportingService?.setLectureContext(lecture)
    }

    func syncAudioPlayer() {
        guard lecture.sourceType == .audio else {
            playerViewModel?.cleanup()
            playerViewModel = nil
            return
        }

        let analyticsContext = LectureAnalyticsContext(lecture: lecture)

        if let playerViewModel {
            playerViewModel.updateAudio(
                lectureTitle: lecture.displayTitle,
                localURL: lecture.audioURL,
                remoteAudioPath: lecture.remoteAudioPath,
                fallbackDuration: lecture.duration,
                analyticsContext: analyticsContext
            )
        } else {
            playerViewModel = LecturePlayerViewModel(
                lectureTitle: lecture.displayTitle,
                audioURL: lecture.audioURL,
                remoteAudioPath: lecture.remoteAudioPath,
                fallbackDuration: lecture.duration,
                analyticsService: analyticsService,
                analyticsContext: analyticsContext
            )
        }
    }

    func startProcessingIfNeeded() async {
        guard processingViewModel == nil, let processingService else {
            return
        }

        let viewModel = LectureProcessingViewModel(
            lecture: lecture,
            repository: repository,
            processingService: processingService,
            analyticsService: analyticsService,
            onLectureUpdated: { [weak self] updatedLecture in
                guard let self else {
                    return
                }

                lecture = updatedLecture
                syncAudioPlayer()
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
        await reloadRepositoryData()

        repositoryObservationTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            for await _ in repository.observeChanges() {
                await reloadRepositoryData()
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

    func open(_ content: LectureDetailContent) {
        analyticsService?.track(
            .detailSectionSelected(
                context: .init(lecture: lecture),
                section: content.analyticsValue
            )
        )
        switch content {
        case .flashcards:
            activeDestination = .flashcards
        case .quiz:
            activeDestination = .quiz
        case .transcript:
            activeRoute = .transcript
        case .keyPoints:
            activeRoute = .keyPoints
        case .summary:
            break
        }
    }

    func retryProcessing() async {
        analyticsService?.track(.processingRetryTapped(context: .init(lecture: lecture)))
        analyticsService?.track(
            .processingStarted(
                context: .init(lecture: lecture),
                plan: nil
            )
        )
        await processingViewModel?.retryProcessing()
    }

    func presentRename() {
        draftTitle = lecture.displayTitle
        isRenameAlertPresented = true
    }

    func presentFolderPicker() {
        isFolderPickerPresented = true
    }

    func saveRenamedLecture() {
        let trimmedTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !isSavingTitle else {
            return
        }

        guard lecture.displayTitle != trimmedTitle else {
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
                showToast(String(localized: "Title updated."))
            } catch {
                lecture = previousLecture
                onLectureUpdated(previousLecture)
                try? await repository.saveLecture(previousLecture)
                presentErrorAlert(String(localized: "Unable to update title right now."))
            }

            isSavingTitle = false
        }
    }

    func copy(_ content: LectureDetailContent) {
        guard let text = content.copyableText(for: lecture, summaryText: summaryText) else {
            return
        }

        UIPasteboard.general.string = text
        analyticsService?.track(
            .sectionCopied(
                context: .init(lecture: lecture),
                section: content.analyticsValue
            )
        )
        showToast(String(localized: "Copied to clipboard."))
    }

    func requestDelete() {
        isDeleteAlertPresented = true
    }

    func createFolder(named name: String) {
        let uniqueName = makeUniqueFolderName(from: name)
        let folder = LectureFolder(name: uniqueName)
        folders.append(folder)

        let folders = self.folders
        Task {
            do {
                try await repository.saveFolders(folders)
            } catch {
                await MainActor.run {
                    self.folders.removeAll { $0.id == folder.id }
                    showToast(String(localized: "Unable to create folder right now."))
                }
            }
        }
    }

    func addLectureToFolder(_ folderID: LectureFolder.ID) {
        updateLectureFolder(folderID)
    }

    func removeLectureFromFolder() {
        updateLectureFolder(nil)
    }

    func confirmDelete() async -> Bool {
        if let errorMessage = await onLectureDeleted(lecture.id) {
            presentErrorAlert(errorMessage)
            return false
        }
        return true
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

    func dismissErrorAlert() {
        isErrorAlertPresented = false
        errorAlertMessage = ""
    }

    func presentErrorAlert(_ message: String) {
        errorAlertMessage = message
        isErrorAlertPresented = true
    }

    private func reloadRepositoryData() async {
        guard let updatedLecture = await repository.fetchLecture(id: lecture.id) else {
            return
        }

        folders = await repository.fetchFolders()
        lecture = updatedLecture
        syncAudioPlayer()
        processingViewModel?.applyCachedLecture(updatedLecture)
        onLectureUpdated(updatedLecture)
    }

    private func updateLectureFolder(_ folderID: LectureFolder.ID?) {
        guard !isSavingFolder else {
            return
        }

        let previousLecture = lecture
        var updatedLecture = lecture
        updatedLecture.folderID = folderID

        lecture = updatedLecture
        onLectureUpdated(updatedLecture)
        isSavingFolder = true
        isFolderPickerPresented = false

        Task {
            do {
                try await repository.saveLecture(updatedLecture)
                let message = if let folderName = folders.first(where: { $0.id == folderID })?.name {
                    String(appLocalized: "Added to \(folderName).")
                } else if folderID == nil {
                    String(localized: "Removed from folder.")
                } else {
                    String(localized: "Added to folder.")
                }
                showToast(message)
            } catch {
                lecture = previousLecture
                onLectureUpdated(previousLecture)
                try? await repository.saveLecture(previousLecture)
                showToast(String(localized: "Unable to update folder right now."))
            }

            isSavingFolder = false
        }
    }

    private func makeUniqueFolderName(from name: String) -> String {
        let existingNames = Set(folders.map(\.name))
        guard !existingNames.contains(name) else {
            var index = 2
            while existingNames.contains("\(name) \(index)") {
                index += 1
            }
            return "\(name) \(index)"
        }
        return name
    }
}
