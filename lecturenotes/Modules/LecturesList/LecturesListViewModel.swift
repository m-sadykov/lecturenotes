import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class LecturesListViewModel {
    private static let lecturePageSize = 50
    private static let minimumRecordingDuration: Duration = .seconds(3)

    struct ToastPresentation: Identifiable {
        enum Content {
            case localized(LocalizedStringResource)
            case custom(String)
        }

        let id = UUID()
        let content: Content
    }

    struct ImportLimitSheetContent: Identifiable {
        enum Kind {
            case audio
            case pdf
        }

        let id = UUID()
        let kind: Kind
        let plan: AppUserPlan

        var title: String {
            switch kind {
            case .audio:
                String(localized: "Recording Too Long")
            case .pdf:
                String(localized: "PDF Too Large")
            }
        }

        var message: String {
            switch (kind, plan) {
            case (.audio, .freemium):
                String(localized: "This recording exceeds your plan limit. Freemium plan allows only 5 minutes per audio import.")
            case (.audio, .premium):
                String(localized: "This recording exceeds your plan limit. Premium plan allows only 100 minutes per audio import.")
            case (.audio, .pro):
                String(localized: "This recording exceeds your plan limit. Pro plan allows only 4 hours per audio import.")
            case (.pdf, .freemium):
                String(localized: "This file exceeds your plan limit. Freemium plan allows only 5 pages per file import.")
            case (.pdf, .premium):
                String(localized: "This file exceeds your plan limit. Premium plan allows only 50 pages per file import.")
            case (.pdf, .pro):
                String(localized: "This file exceeds your plan limit. Pro plan allows only 200 pages per file import.")
            }
        }

        var upgradeTitle: String {
            String(localized: "Upgrade to Pro")
        }

        var upgradeMessage: String {
            switch kind {
            case .audio:
                String(localized: "Record up to 4 hours per recording with Pro.")
            case .pdf:
                String(localized: "Import PDFs up to 200 pages with Pro.")
            }
        }
    }

    enum SaveRecordingResult {
        case saved(Lecture)
        case rejected(message: String)
    }

    enum DeleteLectureResult {
        case deleted
        case rejected(message: String)
    }

    @ObservationIgnored private let repository: LectureRepository
    @ObservationIgnored private let processingService: FirebaseLectureProcessingService?
    @ObservationIgnored private let importManager: LectureImportManager
    @ObservationIgnored private let userProfileService: FirebaseUserProfileService?
    @ObservationIgnored private let analyticsService: AppAnalyticsService?
    @ObservationIgnored private let crashReportingService: CrashReportingService?
    @ObservationIgnored private var repositoryObservationTask: Task<Void, Never>?
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var loadingIndicatorTask: Task<Void, Never>?
    @ObservationIgnored private var pendingRenamePresentationTask: Task<Void, Never>?
    @ObservationIgnored private var pendingDeletionPresentationTask: Task<Void, Never>?
    @ObservationIgnored private var hasLoadedOnce = false

    var lectures: [Lecture] = []
    var folders: [LectureFolder] = []
    var searchText = "" {
        didSet {
            guard oldValue != searchText else {
                return
            }

            resetVisibleLectureCount()
            scheduleSearch()
        }
    }
    var searchResults: [Lecture] = []
    var isSearchPresented = false
    var isSearchAutoPresented = false
    var isSearching = false
    var selectedFolderID: LectureFolder.ID? {
        didSet {
            guard oldValue != selectedFolderID else {
                return
            }

            resetVisibleLectureCount()
            analyticsService?.track(
                .folderFilterApplied(
                    hasFilter: selectedFolderID != nil,
                    filteredCount: filteredLectures.count
                )
            )
        }
    }
    var isLoading = false
    var hasCompletedInitialLoad = false
    var showsInitialLoadingIndicator = false
    var selectedLecture: Lecture?
    var activeSheet: LecturesListActiveSheet?
    var recorderViewModel: RecorderViewModel?
    var toastPresentation: ToastPresentation?
    var removalFeedbackToken = 0
    var importFeedbackToken = 0
    var importLimitFeedbackToken = 0
    var processingStartFeedbackToken = 0
    var processingLimitReachedToken = 0
    var reviewRequestToken = 0
    var isImporterPresented = false
    var isPDFImporterPresented = false
    var isTextImportSheetPresented = false
    var isYouTubeImportSheetPresented = false
    var isImportAlertPresented = false
    var importAlertMessage = ""
    var isErrorAlertPresented = false
    var errorAlertMessage = ""
    var importLimitSheetContent: ImportLimitSheetContent?
    var pendingRenameLecture: Lecture?
    var isRenameAlertPresented = false
    var isSavingTitle = false
    var draftTitle = ""
    var pendingDeletionLecture: Lecture?
    var isAIConsentPresented = false
    var pendingConsentAction: LecturesListPendingConsentAction?
    var pendingTextImportLecture: Lecture?
    var pendingYouTubeImportLecture: Lecture?
    var visibleLectureCount: Int
    private var hasReceivedRepositoryUpdate = false

    init(
        repository: LectureRepository,
        processingService: FirebaseLectureProcessingService? = nil,
        userProfileService: FirebaseUserProfileService? = nil,
        analyticsService: AppAnalyticsService? = nil,
        crashReportingService: CrashReportingService? = nil
    ) {
        self.repository = repository
        self.processingService = processingService
        self.userProfileService = userProfileService
        self.analyticsService = analyticsService
        self.crashReportingService = crashReportingService
        importManager = LectureImportManager()
        visibleLectureCount = Self.lecturePageSize
    }

    init(
        repository: LectureRepository,
        processingService: FirebaseLectureProcessingService? = nil,
        importManager: LectureImportManager,
        userProfileService: FirebaseUserProfileService? = nil,
        analyticsService: AppAnalyticsService? = nil,
        crashReportingService: CrashReportingService? = nil
    ) {
        self.repository = repository
        self.processingService = processingService
        self.importManager = importManager
        self.userProfileService = userProfileService
        self.analyticsService = analyticsService
        self.crashReportingService = crashReportingService
        visibleLectureCount = Self.lecturePageSize
    }

    deinit {
        repositoryObservationTask?.cancel()
        searchTask?.cancel()
        loadingIndicatorTask?.cancel()
        pendingRenamePresentationTask?.cancel()
        pendingDeletionPresentationTask?.cancel()
    }

    var filteredLectures: [Lecture] {
        let sourceLectures = hasActiveSearchQuery ? searchResults : lectures

        return sourceLectures.filter { lecture in
            let matchesFolder = selectedFolderID == nil || lecture.folderID == selectedFolderID
            return matchesFolder
        }
    }

    var displayedLectures: [Lecture] {
        Array(filteredLectures.prefix(visibleLectureCount))
    }

    var hasMoreLecturesToDisplay: Bool {
        filteredLectures.count > visibleLectureCount
    }

    var hasActiveSearchQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func lecture(withID lectureID: Lecture.ID) -> Lecture? {
        lectures.first(where: { $0.id == lectureID })
    }

    func showToast(_ message: String) {
        let toastPresentation = ToastPresentation(content: .custom(message))
        self.toastPresentation = toastPresentation

        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                guard self.toastPresentation?.id == toastPresentation.id else {
                    return
                }
                self.toastPresentation = nil
            }
        }
    }

    func showLocalizedToast(_ message: LocalizedStringResource) {
        let toastPresentation = ToastPresentation(content: .localized(message))
        self.toastPresentation = toastPresentation

        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                guard self.toastPresentation?.id == toastPresentation.id else {
                    return
                }
                self.toastPresentation = nil
            }
        }
    }

    func dismissImportAlert() {
        isImportAlertPresented = false
        importAlertMessage = ""
    }

    func dismissErrorAlert() {
        isErrorAlertPresented = false
        errorAlertMessage = ""
    }

    func dismissImportLimitSheet() {
        importLimitSheetContent = nil
    }

    func dismissDeletionAlert() {
        pendingDeletionPresentationTask?.cancel()
        pendingDeletionLecture = nil
    }

    func dismissRenameAlert() {
        pendingRenamePresentationTask?.cancel()
        pendingRenameLecture = nil
        isRenameAlertPresented = false
        isSavingTitle = false
        draftTitle = ""
    }

    func dismissTextImportSheet() {
        isTextImportSheetPresented = false
    }

    func dismissYouTubeImportSheet() {
        isYouTubeImportSheetPresented = false
    }

    func dismissAIConsent() {
        isAIConsentPresented = false
        pendingConsentAction = nil
    }

    func presentActionSheet(for lectureID: Lecture.ID) {
        activeSheet = .actions(lectureID)
    }

    func presentFolderPicker(for lectureID: Lecture.ID) {
        activeSheet = .folderPicker(lectureID)
    }

    func closeActiveSheet() {
        activeSheet = nil
    }

    func openLecture(_ lecture: Lecture) {
        analyticsService?.track(.lectureOpened(context: .init(lecture: lecture)))
        crashReportingService?.setCurrentScreen("lecture_detail")
        crashReportingService?.setLectureContext(lecture)
        crashReportingService?.breadcrumb(
            "lecture_opened",
            metadata: [
                "lecture_id": lecture.id.uuidString,
                "source_type": lecture.sourceType.rawValue,
            ]
        )
        selectedLecture = lecture
    }

    func presentSearch() {
        isSearchAutoPresented = false
        isSearchPresented = true
    }

    func presentSearchFromScroll() {
        guard !hasActiveSearchQuery, !isSearchPresented else {
            return
        }

        isSearchAutoPresented = true
    }

    func hideSearchForScrollIfNeeded() {
        guard !hasActiveSearchQuery, !isSearchPresented else {
            return
        }

        isSearchAutoPresented = false
    }

    func clearSearch() {
        searchText = ""
    }

    func dismissSearch() {
        searchTask?.cancel()
        searchText = ""
        searchResults = []
        isSearching = false
        isSearchPresented = false
        isSearchAutoPresented = false
    }

    func requestDelete(_ lecture: Lecture) {
        activeSheet = nil
        pendingDeletionPresentationTask?.cancel()
        pendingDeletionLecture = nil
        pendingDeletionPresentationTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, !Task.isCancelled else {
                return
            }
            pendingDeletionLecture = lecture
            pendingDeletionPresentationTask = nil
        }
    }

    func requestRename(_ lecture: Lecture) {
        activeSheet = nil
        pendingRenamePresentationTask?.cancel()
        pendingRenameLecture = nil
        isRenameAlertPresented = false
        draftTitle = lecture.displayTitle
        pendingRenamePresentationTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, !Task.isCancelled else {
                return
            }
            pendingRenameLecture = lecture
            isRenameAlertPresented = true
            pendingRenamePresentationTask = nil
        }
    }

    func saveRenamedLecture() {
        guard let lecture = pendingRenameLecture else {
            return
        }

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

        handleLectureUpdated(renamedLecture)
        isSavingTitle = true

        Task {
            do {
                try await repository.saveLecture(renamedLecture)
            } catch {
                handleLectureUpdated(previousLecture)
                try? await repository.saveLecture(previousLecture)
                presentErrorAlert(String(localized: "Unable to update title right now."))
            }

            isSavingTitle = false
            pendingRenameLecture = nil
        }
    }

    func handleLectureUpdated(_ updatedLecture: Lecture) {
        replaceLecture(updatedLecture)
        if selectedLecture?.id == updatedLecture.id {
            selectedLecture = updatedLecture
        }
    }

    func handleLectureDeletedNavigation(_ lectureID: Lecture.ID) {
        if selectedLecture?.id == lectureID {
            selectedLecture = nil
        }
    }

    func finishTextImportDismissal() {
        guard let lecture = pendingTextImportLecture else {
            return
        }

        pendingTextImportLecture = nil
        selectedLecture = lecture
    }

    func finishYouTubeImportDismissal() {
        guard let lecture = pendingYouTubeImportLecture else {
            return
        }

        pendingYouTubeImportLecture = nil
        selectedLecture = lecture
    }

    func requestFlow(_ action: LecturesListPendingConsentAction, hasConfirmedAIProcessingConsent: Bool) {
        guard processingService != nil else {
            present(action)
            return
        }

        if hasConfirmedAIProcessingConsent {
            present(action)
        } else {
            pendingConsentAction = action
            isAIConsentPresented = true
        }
    }

    func requestRecordingFlow(hasConfirmedAIProcessingConsent: Bool) async {
        guard processingService != nil else {
            present(.record)
            return
        }

        guard await canStartRecordingFlow() else {
            return
        }

        if hasConfirmedAIProcessingConsent {
            present(.record)
        } else {
            pendingConsentAction = .record
            isAIConsentPresented = true
        }
    }

    func continuePendingConsentAction() {
        let action = pendingConsentAction
        isAIConsentPresented = false
        pendingConsentAction = nil

        guard let action else {
            recorderViewModel = RecorderViewModel(
                analyticsService: analyticsService,
                crashReportingService: crashReportingService,
                plan: currentPlan
            )
            return
        }

        present(action)
    }

    func createFolder(named name: String) {
        let uniqueName = makeUniqueFolderName(from: name)
        let folder = LectureFolder(name: uniqueName)
        folders.append(folder)
        persistFolders()
    }

    func addLecture(_ lectureID: Lecture.ID, toFolder folderID: LectureFolder.ID) {
        guard let lectureIndex = lectures.firstIndex(where: { $0.id == lectureID }) else {
            return
        }

        lectures[lectureIndex].folderID = folderID
        selectedFolderID = folderID
        persistLecture(at: lectureIndex)
        activeSheet = nil
    }

    func removeLectureFromFolder(_ lectureID: Lecture.ID) -> String? {
        guard let lectureIndex = lectures.firstIndex(where: { $0.id == lectureID }) else {
            return nil
        }

        let removedFolderID = lectures[lectureIndex].folderID
        let folderName = folders.first(where: { $0.id == removedFolderID })?.name
        lectures[lectureIndex].folderID = nil

        if selectedFolderID == removedFolderID {
            selectedFolderID = nil
        }

        persistLecture(at: lectureIndex)
        return folderName
    }

    func deleteFolder(_ folderID: LectureFolder.ID) {
        folders.removeAll { $0.id == folderID }

        for lectureIndex in lectures.indices where lectures[lectureIndex].folderID == folderID {
            lectures[lectureIndex].folderID = nil
        }

        if selectedFolderID == folderID {
            selectedFolderID = nil
        }

        persistFolders()
        persistAllLectures()
    }

    func saveRecording(_ recording: RecorderViewModel.RecordingDraft) async -> SaveRecordingResult {
        guard recording.duration >= Self.minimumRecordingDuration else {
            analyticsService?.track(
                .contentCreateFailed(
                    sourceType: "recording",
                    entryPoint: "mini_recorder",
                    plan: currentPlan,
                    reason: String(localized: "Recording must be at least 3 seconds long.")
                )
            )
            return .rejected(message: String(localized: "Recording must be at least 3 seconds long."))
        }

        if let validationMessage = await validateRecordingDuration(recording.duration) {
            analyticsService?.track(
                .contentCreateFailed(
                    sourceType: "recording",
                    entryPoint: "mini_recorder",
                    plan: currentPlan,
                    reason: validationMessage
                )
            )
            return .rejected(message: validationMessage)
        }

        let lectureStatus: LectureStatus = processingService == nil ? .ready : LectureSourceType.audio.processingStartStatus
        let lecture = Lecture(
            title: LectureLocalizedTitleKey.newRecording.rawValue,
            sourceType: .audio,
            audioURL: recording.audioURL,
            createdAt: recording.createdAt,
            duration: recording.duration,
            status: lectureStatus,
            transcript: "",
            summaryShort: "",
            summaryLong: "",
            flashcards: [],
            quiz: []
        )

        lectures.insert(lecture, at: 0)
        do {
            try await repository.saveLecture(lecture)
            analyticsService?.track(
                .contentCreateSuccess(
                    context: .init(lecture: lecture),
                    plan: currentPlan
                )
            )
            startProcessingIfNeeded(for: lecture)
            return .saved(lecture)
        } catch {
            lectures.removeAll { $0.id == lecture.id }
            crashReportingService?.recordNonFatal(
                error,
                reason: "recording_save_failed",
                metadata: [
                    "source_type": "recording",
                    "lecture_id": lecture.id.uuidString,
                ]
            )
            analyticsService?.track(
                .contentCreateFailed(
                    sourceType: "recording",
                    entryPoint: "mini_recorder",
                    plan: currentPlan,
                    reason: String(localized: "Unable to save recording right now.")
                )
            )
            return .rejected(message: String(localized: "Unable to save recording right now."))
        }
    }

    func saveRecordingDraft(_ recording: RecorderViewModel.RecordingDraft) async {
        guard recording.duration >= Self.minimumRecordingDuration else {
            analyticsService?.track(
                .contentCreateFailed(
                    sourceType: "recording",
                    entryPoint: "mini_recorder",
                    plan: currentPlan,
                    reason: String(localized: "Recording must be at least 3 seconds long.")
                )
            )
            showLocalizedToast("Recording must be at least 3 seconds long.")
            return
        }

        let result = await saveRecording(recording)

        switch result {
        case .saved(let savedLecture):
            selectedLecture = savedLecture
        case .rejected(let message):
            presentErrorAlert(message)
        }
    }

    func importAudio(from sourceURL: URL) async -> SaveRecordingResult {
        let lectureID = UUID()

        do {
            let importedAudio = try await importManager.importAudio(from: sourceURL, lectureID: lectureID)

            if let validationMessage = await validateAudioImportDuration(importedAudio.duration) {
                try? FileManager.default.removeItem(at: importedAudio.localURL)
                return .rejected(message: validationMessage)
            }

            if let validationMessage = await validateProcessingAvailability() {
                try? FileManager.default.removeItem(at: importedAudio.localURL)
                return .rejected(message: validationMessage)
            }

            let lectureStatus: LectureStatus = processingService == nil ? .ready : LectureSourceType.audio.processingStartStatus
            let lecture = Lecture(
                id: lectureID,
                title: importedAudio.suggestedTitle,
                sourceType: .audio,
                audioURL: importedAudio.localURL,
                createdAt: importedAudio.createdAt,
                duration: importedAudio.duration,
                status: lectureStatus,
                transcript: "",
                summaryShort: "",
                summaryLong: "",
                flashcards: [],
                quiz: []
            )

            lectures.insert(lecture, at: 0)

            do {
                try await repository.saveLecture(lecture)
                analyticsService?.track(
                    .contentCreateSuccess(
                        context: .init(lecture: lecture),
                        plan: currentPlan
                    )
                )
                startProcessingIfNeeded(for: lecture)
                return .saved(lecture)
            } catch {
                lectures.removeAll { $0.id == lecture.id }
                try? FileManager.default.removeItem(at: importedAudio.localURL)
                crashReportingService?.recordNonFatal(
                    error,
                    reason: "audio_import_failed",
                    metadata: [
                        "source_type": "audio",
                        "lecture_id": lecture.id.uuidString,
                    ]
                )
                analyticsService?.track(
                    .contentCreateFailed(
                        sourceType: "audio",
                        entryPoint: "file_importer",
                        plan: currentPlan,
                        reason: String(localized: "Unable to save imported audio right now.")
                    )
                )
                return .rejected(message: String(localized: "Unable to save imported audio right now."))
            }
        } catch {
            crashReportingService?.recordNonFatal(
                error,
                reason: "audio_import_failed",
                metadata: [
                    "source_type": "audio",
                ]
            )
            analyticsService?.track(
                .contentCreateFailed(
                    sourceType: "audio",
                    entryPoint: "file_importer",
                    plan: currentPlan,
                    reason: error.localizedDescription
                )
            )
            return .rejected(message: error.localizedDescription)
        }
    }

    func importText(_ text: String) async -> SaveRecordingResult {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            analyticsService?.track(
                .contentCreateFailed(
                    sourceType: "text",
                    entryPoint: "text_import_sheet",
                    plan: currentPlan,
                    reason: String(localized: "Enter some lecture text first.")
                )
            )
            return .rejected(message: String(localized: "Enter some lecture text first."))
        }

        if let validationMessage = await validateProcessingAvailability() {
            analyticsService?.track(
                .contentCreateFailed(
                    sourceType: "text",
                    entryPoint: "text_import_sheet",
                    plan: currentPlan,
                    reason: validationMessage
                )
            )
            return .rejected(message: validationMessage)
        }

        let textDocument = importManager.makeTextDocument(from: trimmedText)
        return await saveImportedTextLecture(
            textDocument
        )
    }

    func importPDF(from sourceURL: URL) async -> SaveRecordingResult {
        do {
            let importedPDF = try await importManager.importPDF(from: sourceURL)

            if let validationMessage = await validatePDFPageCount(importedPDF.pageCount) {
                return .rejected(message: validationMessage)
            }

            if let validationMessage = await validateProcessingAvailability() {
                return .rejected(message: validationMessage)
            }

            return await saveImportedTextLecture(importedPDF)
        } catch {
            crashReportingService?.recordNonFatal(
                error,
                reason: "pdf_import_failed",
                metadata: [
                    "source_type": "pdf",
                ]
            )
            analyticsService?.track(
                .contentCreateFailed(
                    sourceType: "pdf",
                    entryPoint: "file_importer",
                    plan: currentPlan,
                    reason: error.localizedDescription
                )
            )
            return .rejected(message: error.localizedDescription)
        }
    }

    func submitTextImport(_ text: String) async -> String? {
        let result = await importText(text)

        switch result {
        case .saved(let lecture):
            importFeedbackToken += 1
            pendingTextImportLecture = lecture
            isTextImportSheetPresented = false
            return nil
        case .rejected(let message):
            return message
        }
    }

    func submitYouTubeImport(_ urlString: String) async -> YouTubeImportAlertError? {
        let result = await importYouTube(urlString: urlString)

        switch result {
        case .saved(let lecture):
            importFeedbackToken += 1
            pendingYouTubeImportLecture = lecture
            isYouTubeImportSheetPresented = false
            return nil
        case .rejected(let error):
            return error
        }
    }

    private func saveImportedTextLecture(
        _ textDocument: LectureImportManager.ImportedTextDocument
    ) async -> SaveRecordingResult {
        let lectureStatus: LectureStatus = processingService == nil ? .ready : textDocument.sourceType.processingStartStatus
        let lecture = Lecture(
            id: UUID(),
            title: textDocument.suggestedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? importManager.suggestedTitle(for: textDocument.text) : textDocument.suggestedTitle,
            sourceType: textDocument.sourceType,
            audioURL: nil,
            pdfPageCount: textDocument.pageCount,
            createdAt: textDocument.createdAt,
            duration: importManager.estimateReadingDuration(for: textDocument.text),
            status: lectureStatus,
            transcript: textDocument.text,
            summaryShort: "",
            summaryLong: "",
            flashcards: [],
            quiz: []
        )

        lectures.insert(lecture, at: 0)

        do {
            try await repository.saveLecture(lecture)
            analyticsService?.track(
                .contentCreateSuccess(
                    context: .init(lecture: lecture),
                    plan: currentPlan
                )
            )
            startProcessingIfNeeded(for: lecture)
            return .saved(lecture)
        } catch {
            lectures.removeAll { $0.id == lecture.id }
            let message = switch textDocument.sourceType {
            case .pdf:
                String(localized: "Unable to save imported PDF right now.")
            case .text:
                String(localized: "Unable to save imported text right now.")
            case .audio, .youtube:
                String(localized: "Unable to save imported content right now.")
            }
            analyticsService?.track(
                .contentCreateFailed(
                    sourceType: textDocument.sourceType.rawValue,
                    entryPoint: textDocument.sourceType == .pdf ? "file_importer" : "text_import_sheet",
                    plan: currentPlan,
                    reason: message
                )
            )
            crashReportingService?.recordNonFatal(
                error,
                reason: textDocument.sourceType == .pdf ? "pdf_import_failed" : "text_import_failed",
                metadata: [
                    "source_type": textDocument.sourceType.rawValue,
                    "lecture_id": lecture.id.uuidString,
                ]
            )
            return .rejected(message: message)
        }
    }

    func importYouTube(urlString: String) async -> YouTubeImportResult {
        let trimmedURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let sourceURL = URL(string: trimmedURLString), sourceURL.host() != nil else {
            analyticsService?.track(
                .contentCreateFailed(
                    sourceType: "youtube",
                    entryPoint: "youtube_import_sheet",
                    plan: currentPlan,
                    reason: String(localized: "Enter a valid YouTube link.")
                )
            )
            return .rejected(.invalidLink)
        }

        guard let videoID = importManager.parseYouTubeVideoID(from: sourceURL) else {
            analyticsService?.track(
                .contentCreateFailed(
                    sourceType: "youtube",
                    entryPoint: "youtube_import_sheet",
                    plan: currentPlan,
                    reason: String(localized: "Enter a valid YouTube link.")
                )
            )
            return .rejected(.invalidLink)
        }

        if let validationError = await validateYouTubeImportAvailability() {
            analyticsService?.track(
                .contentCreateFailed(
                    sourceType: "youtube",
                    entryPoint: "youtube_import_sheet",
                    plan: currentPlan,
                    reason: validationError.message
                )
            )
            return .rejected(validationError)
        }

        let lectureStatus: LectureStatus = if processingService == nil {
            .failed
        } else {
            .transcribing
        }
        let lecture = Lecture(
            id: UUID(),
            title: LectureLocalizedTitleKey.youTubeImport.rawValue,
            sourceType: .youtube,
            audioURL: nil,
            sourceURL: sourceURL,
            youtubeVideoID: videoID,
            createdAt: .now,
            duration: .seconds(30),
            status: lectureStatus,
            transcript: "",
            summaryShort: "",
            summaryLong: "",
            flashcards: [],
            quiz: [],
            processingErrorMessage: processingService == nil ? String(localized: "YouTube import requires backend processing.") : nil
        )

        lectures.insert(lecture, at: 0)

        do {
            try await repository.saveLecture(lecture)
            analyticsService?.track(
                .contentCreateSuccess(
                    context: .init(lecture: lecture),
                    plan: currentPlan
                )
            )
            startProcessingIfNeeded(for: lecture)
            return .saved(lecture)
        } catch {
            lectures.removeAll { $0.id == lecture.id }
            crashReportingService?.recordNonFatal(
                error,
                reason: "youtube_import_failed",
                metadata: [
                    "source_type": "youtube",
                    "lecture_id": lecture.id.uuidString,
                ]
            )
            analyticsService?.track(
                .contentCreateFailed(
                    sourceType: "youtube",
                    entryPoint: "youtube_import_sheet",
                    plan: currentPlan,
                    reason: String(localized: "Unable to save YouTube import right now.")
                )
            )
            return .rejected(.saveFailed)
        }
    }

    func deleteLecture(_ lectureID: Lecture.ID) async -> DeleteLectureResult {
        guard let lectureIndex = lectures.firstIndex(where: { $0.id == lectureID }) else {
            return .deleted
        }

        let deletedLecture = lectures[lectureIndex]
        let searchResultIndex = searchResults.firstIndex(where: { $0.id == lectureID })
        let deletedSelectedLecture = selectedLecture?.id == lectureID ? selectedLecture : nil

        lectures.remove(at: lectureIndex)
        if let searchResultIndex {
            searchResults.remove(at: searchResultIndex)
        }
        if deletedSelectedLecture != nil {
            selectedLecture = nil
        }

        do {
            try await repository.deleteLecture(id: lectureID)
            return .deleted
        } catch {
            lectures.insert(deletedLecture, at: min(lectureIndex, lectures.count))
            if let searchResultIndex {
                let restoredSearchResultIndex = min(searchResultIndex, searchResults.count)
                searchResults.insert(deletedLecture, at: restoredSearchResultIndex)
            }
            if let deletedSelectedLecture {
                selectedLecture = deletedSelectedLecture
            }
            crashReportingService?.recordNonFatal(
                error,
                reason: "lecture_delete_failed",
                metadata: [
                    "lecture_id": lectureID.uuidString,
                    "source_type": deletedLecture.sourceType.rawValue,
                ]
            )
            return .rejected(message: String(localized: "Unable to delete lecture right now."))
        }
    }

    func confirmPendingDeletion() async {
        guard let lecture = pendingDeletionLecture else {
            return
        }

        let result = await deleteLecture(lecture.id)
        pendingDeletionLecture = nil

        if case .rejected(let message) = result {
            importAlertMessage = message
            isImportAlertPresented = true
        }
    }

    func handleAudioImportResult(_ result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                presentImportError(String(localized: "No audio file was selected."))
                return
            }

            let importResult = await importAudio(from: url)
            handleImportResult(importResult)
        case .failure(let error):
            presentImportError(String(localized: "Import failed: \(error.localizedDescription)"))
        }
    }

    func handlePDFImportResult(_ result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                presentImportError(String(localized: "No PDF file was selected."))
                return
            }

            processingStartFeedbackToken += 1
            let importResult = await importPDF(from: url)
            handleImportResult(importResult)
        case .failure(let error):
            presentImportError(String(localized: "Import failed: \(error.localizedDescription)"))
        }
    }

    func load() async {
        guard !hasLoadedOnce, !isLoading else {
            return
        }

        startObservingRepositoryIfNeeded()
        hasReceivedRepositoryUpdate = false
        hasCompletedInitialLoad = false
        isLoading = true
        showsInitialLoadingIndicator = false
        scheduleInitialLoadingIndicator()
        await repository.start()
        await reloadRepositoryData()
        await waitForInitialRepositoryContentIfNeeded()
        loadingIndicatorTask?.cancel()
        loadingIndicatorTask = nil
        showsInitialLoadingIndicator = false
        isLoading = false
        hasCompletedInitialLoad = true
        hasLoadedOnce = true
        crashReportingService?.setCurrentScreen("home")
        crashReportingService?.setCurrentFlow("home")
        crashReportingService?.breadcrumb(
            "home_load_completed",
            metadata: [
                "lectures_count": lectures.count,
                "folders_count": folders.count,
            ]
        )
        analyticsService?.track(
            .homeOpened(
                lecturesCount: lectures.count,
                foldersCount: folders.count,
                plan: currentPlan
            )
        )
    }

    func loadMoreLecturesIfNeeded(currentLectureID: Lecture.ID) {
        guard hasMoreLecturesToDisplay else {
            return
        }

        guard displayedLectures.last?.id == currentLectureID else {
            return
        }

        visibleLectureCount += Self.lecturePageSize
    }

    func replaceLecture(_ lecture: Lecture) {
        if let index = lectures.firstIndex(where: { $0.id == lecture.id }) {
            lectures[index] = lecture
        } else {
            lectures.insert(lecture, at: 0)
        }
    }

    private func makeUniqueFolderName(from name: String) -> String {
        let existingNames = Set(folders.map(\.name))
        guard existingNames.contains(name) else {
            return name
        }

        var index = 2
        while existingNames.contains("\(name) \(index)") {
            index += 1
        }
        return "\(name) \(index)"
    }

    private func persistFolders() {
        let folders = self.folders
        Task {
            try? await repository.saveFolders(folders)
        }
    }

    private func persistLecture(at index: Int) {
        guard lectures.indices.contains(index) else {
            return
        }

        let lecture = lectures[index]
        Task {
            try? await repository.saveLecture(lecture)
        }
    }

    private func persistAllLectures() {
        let lectures = self.lectures
        Task {
            for lecture in lectures {
                try? await repository.saveLecture(lecture)
            }
        }
    }

    private func startProcessingIfNeeded(for lecture: Lecture) {
        guard let processingService else {
            return
        }

        crashReportingService?.setLectureContext(lecture)
        crashReportingService?.setCurrentFlow("processing")
        crashReportingService?.setProcessingStage(lecture.processingStartStatus.rawValue)
        analyticsService?.track(
            .processingStarted(
                context: .init(lecture: lecture),
                plan: currentPlan
            )
        )

        Task {
            var lectureToProcess = lecture

            do {
                lectureToProcess = try await processingService.startProcessing(for: lectureToProcess)
                replaceLecture(lectureToProcess)
            } catch {
                if let processingError = error as? FirebaseLectureProcessingError,
                   case .processingLimitExceeded = processingError {
                    processingLimitReachedToken += 1
                }

                lectureToProcess.status = .failed
                lectureToProcess.processingErrorMessage = error.localizedDescription
                replaceLecture(lectureToProcess)
                crashReportingService?.breadcrumb(
                    "processing_request_failed",
                    metadata: [
                        "lecture_id": lecture.id.uuidString,
                        "source_type": lecture.sourceType.rawValue,
                        "processing_stage": lecture.processingStartStatus.rawValue,
                    ]
                )
                analyticsService?.track(
                    .processingFailed(
                        context: .init(lecture: lectureToProcess),
                        plan: currentPlan,
                        stage: lecture.sourceType.processingStartStatus.rawValue,
                        reason: error.localizedDescription
                    )
                )
            }
        }
    }

    private func startObservingRepositoryIfNeeded() {
        guard repositoryObservationTask == nil else {
            return
        }

        repositoryObservationTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            for await _ in repository.observeChanges() {
                hasReceivedRepositoryUpdate = true
                await reloadRepositoryData()
            }
        }
    }

    private func reloadRepositoryData() async {
        let previousLectures = lectures
        let fetchedFolders = await repository.fetchFolders()
        let fetchedLectures = await repository.fetchLectures()

        folders = fetchedFolders
        lectures = fetchedLectures
        trackProcessingStatusChanges(from: previousLectures, to: lectures)
        if shouldRequestReview(previousLectures: previousLectures, updatedLectures: lectures) {
            reviewRequestToken += 1
        }

        if hasActiveSearchQuery {
            await refreshSearchResults()
        } else {
            searchResults = []
        }

        if let selectedLectureID = selectedLecture?.id {
            selectedLecture = lectures.first(where: { $0.id == selectedLectureID })
        }
    }

    private func shouldRequestReview(previousLectures: [Lecture], updatedLectures: [Lecture]) -> Bool {
        let previousStatuses = Dictionary(uniqueKeysWithValues: previousLectures.map { ($0.id, $0.status) })

        return updatedLectures.contains { lecture in
            guard let previousStatus = previousStatuses[lecture.id] else {
                return false
            }

            return previousStatus != .ready && lecture.status == .ready
        }
    }

    private func waitForInitialRepositoryContentIfNeeded() async {
        guard lectures.isEmpty else {
            return
        }

        let deadline = ContinuousClock.now + .seconds(2.5)
        await waitUntilRepositoryUpdates(deadline: deadline)

        await reloadRepositoryData()
    }

    private func waitUntilRepositoryUpdates(deadline: ContinuousClock.Instant) async {
        while !hasReceivedRepositoryUpdate, ContinuousClock.now < deadline {
            if Task.isCancelled {
                return
            }

            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    private func resetVisibleLectureCount() {
        visibleLectureCount = Self.lecturePageSize
    }

    private func scheduleInitialLoadingIndicator() {
        loadingIndicatorTask?.cancel()
        loadingIndicatorTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard let self, !Task.isCancelled, !hasCompletedInitialLoad else {
                return
            }

            showsInitialLoadingIndicator = true
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()

        guard hasActiveSearchQuery else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        searchTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch {
                return
            }

            guard let self, !Task.isCancelled else {
                return
            }

            await self.refreshSearchResults(for: query)
        }
    }

    private func refreshSearchResults() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        await refreshSearchResults(for: query)
    }

    private func refreshSearchResults(for query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        let results = await repository.searchLectures(matching: query)

        guard !Task.isCancelled else {
            return
        }

        let latestQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard latestQuery == query else {
            return
        }

        searchResults = results
        isSearching = false
        analyticsService?.track(
            .searchUsed(
                queryLength: query.count,
                resultsCount: results.count,
                hasFolderFilter: selectedFolderID != nil
            )
        )
    }

    private func trackProcessingStatusChanges(from previousLectures: [Lecture], to updatedLectures: [Lecture]) {
        let previousLecturesByID = Dictionary(uniqueKeysWithValues: previousLectures.map { ($0.id, $0) })

        for lecture in updatedLectures {
            guard let previousLecture = previousLecturesByID[lecture.id] else {
                continue
            }

            guard previousLecture.status != lecture.status else {
                continue
            }

            if previousLecture.status != .ready, lecture.status == .ready {
                analyticsService?.track(
                    .processingCompleted(
                        context: .init(lecture: lecture),
                        plan: currentPlan,
                        flashcardsCount: lecture.flashcards.count,
                        quizCount: lecture.quiz.count
                    )
                )
            } else if previousLecture.status != .failed, lecture.status == .failed {
                analyticsService?.track(
                    .processingFailed(
                        context: .init(lecture: lecture),
                        plan: currentPlan,
                        stage: previousLecture.status.rawValue,
                        reason: lecture.processingErrorMessage ?? String(localized: "Unknown processing error")
                    )
                )
            }
        }
    }
    
    private func handleImportResult(_ result: SaveRecordingResult) {
        switch result {
        case .saved(let lecture):
            importFeedbackToken += 1
            selectedLecture = lecture
        case .rejected(let message):
            guard importLimitSheetContent == nil else {
                return
            }
            presentImportError(message)
        }
    }

    private func presentImportError(_ message: String) {
        importAlertMessage = message
        isImportAlertPresented = true
    }

    func presentErrorAlert(_ message: String) {
        errorAlertMessage = message
        isErrorAlertPresented = true
    }

    private func present(_ action: LecturesListPendingConsentAction) {
        let sourceType: String = switch action {
        case .record:
            "recording"
        case .importAudio:
            "audio"
        case .importText:
            "text"
        case .importPDF:
            "pdf"
        case .importYouTube:
            "youtube"
        }
        analyticsService?.track(
            .contentCreateStarted(
                sourceType: sourceType,
                entryPoint: "quick_actions",
                plan: currentPlan
            )
        )

        switch action {
        case .record:
            recorderViewModel = RecorderViewModel(
                limit: currentRecordingLimit,
                analyticsService: analyticsService,
                crashReportingService: crashReportingService,
                plan: currentPlan
            )
        case .importAudio:
            isImporterPresented = true
        case .importText:
            isTextImportSheetPresented = true
        case .importPDF:
            isPDFImporterPresented = true
        case .importYouTube:
            isYouTubeImportSheetPresented = true
        }
    }

    private var currentRecordingLimit: Duration {
        userProfileService?.currentProfile?.recordingLimitDuration ?? .seconds(5 * 60)
    }

    private var currentPlan: AppUserPlan? {
        userProfileService?.currentProfile?.plan
    }

    private func canStartRecordingFlow() async -> Bool {
        guard processingService != nil else {
            return true
        }

        let userProfile = await currentUserProfile()
        guard userProfile?.canStartProcessing ?? true else {
            processingLimitReachedToken += 1
            return false
        }

        return true
    }

    private func validateRecordingDuration(_ duration: Duration) async -> String? {
        let userProfile = await currentUserProfile()
        let limit = userProfile?.recordingLimitDuration ?? .seconds(5 * 60)
        guard duration <= limit else {
            analyticsService?.track(
                .contentLimitHit(
                    sourceType: "recording",
                    limitType: "duration",
                    plan: userProfile?.plan,
                    allowedValue: limit.secondsValue,
                    actualValue: duration.secondsValue
                )
            )
            return String(
                localized: "Your \((userProfile?.plan ?? .freemium).title) plan allows up to \(LectureFormatters.durationText(limit)) per recording."
            )
        }

        return nil
    }

    private func validateAudioImportDuration(_ duration: Duration) async -> String? {
        let userProfile = await currentUserProfile()
        let limit = userProfile?.audioImportLimitDuration ?? .seconds(5 * 60)
        guard duration <= limit else {
            presentImportLimitSheet(
                makeAudioImportLimitSheetContent(userProfile: userProfile)
            )
            analyticsService?.track(
                .contentLimitHit(
                    sourceType: "audio",
                    limitType: "duration",
                    plan: userProfile?.plan,
                    allowedValue: limit.secondsValue,
                    actualValue: duration.secondsValue
                )
            )
            return String(
                localized: "Your \((userProfile?.plan ?? .freemium).title) plan allows audio imports up to \(LectureFormatters.durationText(limit)) per file."
            )
        }

        return nil
    }

    private func validatePDFPageCount(_ pageCount: Int?) async -> String? {
        guard let pageCount else {
            return nil
        }

        let userProfile = await currentUserProfile()
        let limit = userProfile?.pdfPageLimit ?? 5
        guard pageCount <= limit else {
            presentImportLimitSheet(
                makePDFImportLimitSheetContent(userProfile: userProfile)
            )
            analyticsService?.track(
                .contentLimitHit(
                    sourceType: "pdf",
                    limitType: "page_count",
                    plan: userProfile?.plan,
                    allowedValue: Double(limit),
                    actualValue: Double(pageCount)
                )
            )
            return String(
                localized: "Your \((userProfile?.plan ?? .freemium).title) plan allows PDF imports up to \(limit) pages per file."
            )
        }

        return nil
    }

    private func validateProcessingAvailability() async -> String? {
        guard processingService != nil else {
            return nil
        }

        let userProfile = await currentUserProfile()
        guard userProfile?.canStartProcessing ?? true else {
            processingLimitReachedToken += 1
            let remainingCount = max(userProfile?.processingQuota.remainingCount ?? 0, 0)
            analyticsService?.track(
                .contentLimitHit(
                    sourceType: "processing",
                    limitType: "quota",
                    plan: userProfile?.plan,
                    allowedValue: Double(userProfile?.processingQuota.totalCount ?? 0),
                    actualValue: Double(userProfile?.processingQuota.usedCount ?? 0)
                )
            )
            return String(
                localized: "You have \(remainingCount) processing attempts left on your \((userProfile?.plan ?? .freemium).title) plan."
            )
        }

        return nil
    }

    private func validateYouTubeImportAvailability() async -> YouTubeImportAlertError? {
        guard processingService != nil else {
            return nil
        }

        let userProfile = await currentUserProfile()
        guard userProfile?.canStartProcessing ?? true else {
            processingLimitReachedToken += 1
            let resolvedPlan = userProfile?.plan ?? .freemium
            let remainingCount = max(userProfile?.processingQuota.remainingCount ?? 0, 0)
            analyticsService?.track(
                .contentLimitHit(
                    sourceType: "processing",
                    limitType: "quota",
                    plan: userProfile?.plan,
                    allowedValue: Double(userProfile?.processingQuota.totalCount ?? 0),
                    actualValue: Double(userProfile?.processingQuota.usedCount ?? 0)
                )
            )
            return .processingLimitReached(
                remainingCount: remainingCount,
                plan: resolvedPlan
            )
        }

        return nil
    }

    private func currentUserProfile() async -> AppUserProfile? {
        if let currentProfile = userProfileService?.currentProfile {
            return currentProfile
        }

        return try? await userProfileService?.ensureCurrentUserProfile()
    }

    private func presentImportLimitSheet(_ content: ImportLimitSheetContent) {
        importLimitSheetContent = content
        importLimitFeedbackToken += 1
    }

    private func makeAudioImportLimitSheetContent(
        userProfile: AppUserProfile?
    ) -> ImportLimitSheetContent {
        return ImportLimitSheetContent(
            kind: .audio,
            plan: userProfile?.plan ?? .freemium
        )
    }

    private func makePDFImportLimitSheetContent(
        userProfile: AppUserProfile?
    ) -> ImportLimitSheetContent {
        return ImportLimitSheetContent(
            kind: .pdf,
            plan: userProfile?.plan ?? .freemium
        )
    }
}

private extension Duration {
    var secondsValue: Double {
        TimeInterval(components.seconds) + (TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000)
    }
}

enum LecturesListActiveSheet: Identifiable {
    case actions(Lecture.ID)
    case folderPicker(Lecture.ID)

    var id: String {
        switch self {
        case .actions(let lectureID):
            "actions-\(lectureID)"
        case .folderPicker(let lectureID):
            "folderPicker-\(lectureID)"
        }
    }
}

enum YouTubeImportResult {
    case saved(Lecture)
    case rejected(YouTubeImportAlertError)
}

enum LecturesListPendingConsentAction {
    case record
    case importAudio
    case importText
    case importPDF
    case importYouTube
}
