import Foundation
import Observation

@MainActor
@Observable
final class LecturesListViewModel {
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
    @ObservationIgnored private var repositoryObservationTask: Task<Void, Never>?
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    var lectures: [Lecture] = []
    var folders: [LectureFolder] = []
    var searchText = "" {
        didSet {
            guard oldValue != searchText else {
                return
            }

            scheduleSearch()
        }
    }
    var searchResults: [Lecture] = []
    var isSearchPresented = false
    var isSearchAutoPresented = false
    var isSearching = false
    var selectedFolderID: LectureFolder.ID?
    var isLoading = false
    var selectedLecture: Lecture?
    var activeSheet: LecturesListActiveSheet?
    var recorderViewModel: RecorderViewModel?
    var toastMessage: String?
    var removalFeedbackToken = 0
    var importFeedbackToken = 0
    var processingStartFeedbackToken = 0
    var isImporterPresented = false
    var isPDFImporterPresented = false
    var isTextImportSheetPresented = false
    var isYouTubeImportSheetPresented = false
    var isImportAlertPresented = false
    var importAlertMessage = ""
    var pendingDeletionLecture: Lecture?
    var isAIConsentPresented = false
    var pendingConsentAction: LecturesListPendingConsentAction?
    var pendingTextImportLecture: Lecture?
    var pendingYouTubeImportLecture: Lecture?

    init(
        repository: LectureRepository,
        processingService: FirebaseLectureProcessingService? = nil,
        userProfileService: FirebaseUserProfileService? = nil
    ) {
        self.repository = repository
        self.processingService = processingService
        self.userProfileService = userProfileService
        importManager = LectureImportManager()
    }

    init(
        repository: LectureRepository,
        processingService: FirebaseLectureProcessingService? = nil,
        importManager: LectureImportManager,
        userProfileService: FirebaseUserProfileService? = nil
    ) {
        self.repository = repository
        self.processingService = processingService
        self.importManager = importManager
        self.userProfileService = userProfileService
    }

    deinit {
        repositoryObservationTask?.cancel()
        searchTask?.cancel()
    }

    var filteredLectures: [Lecture] {
        let sourceLectures = hasActiveSearchQuery ? searchResults : lectures

        return sourceLectures.filter { lecture in
            let matchesFolder = selectedFolderID == nil || lecture.folderID == selectedFolderID
            return matchesFolder
        }
    }

    var hasActiveSearchQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func lecture(withID lectureID: Lecture.ID) -> Lecture? {
        lectures.first(where: { $0.id == lectureID })
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

    func dismissImportAlert() {
        isImportAlertPresented = false
        importAlertMessage = ""
    }

    func dismissDeletionAlert() {
        pendingDeletionLecture = nil
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
        pendingDeletionLecture = lecture
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

    func continuePendingConsentAction() {
        let action = pendingConsentAction
        isAIConsentPresented = false
        pendingConsentAction = nil

        guard let action else {
            recorderViewModel = RecorderViewModel()
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
        let minimumDuration = Duration.seconds(3)
        guard recording.duration >= minimumDuration else {
            return .rejected(message: "Recording must be at least 3 seconds long.")
        }

        if let validationMessage = await validateRecordingDuration(recording.duration) {
            return .rejected(message: validationMessage)
        }

        if let validationMessage = await validateProcessingAvailability() {
            return .rejected(message: validationMessage)
        }

        let lectureStatus: LectureStatus = processingService == nil ? .ready : LectureSourceType.audio.processingStartStatus
        let lecture = Lecture(
            title: "New Recording",
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
            startProcessingIfNeeded(for: lecture)
            return .saved(lecture)
        } catch {
            lectures.removeAll { $0.id == lecture.id }
            return .rejected(message: "Unable to save recording right now.")
        }
    }

    func saveRecordingDraft(_ recording: RecorderViewModel.RecordingDraft) async {
        let result = await saveRecording(recording)

        switch result {
        case .saved(let savedLecture):
            selectedLecture = savedLecture
        case .rejected(let message):
            showToast(message)
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
                startProcessingIfNeeded(for: lecture)
                return .saved(lecture)
            } catch {
                lectures.removeAll { $0.id == lecture.id }
                try? FileManager.default.removeItem(at: importedAudio.localURL)
                return .rejected(message: "Unable to save imported audio right now.")
            }
        } catch {
            return .rejected(message: error.localizedDescription)
        }
    }

    func importText(_ text: String) async -> SaveRecordingResult {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return .rejected(message: "Enter some lecture text first.")
        }

        if let validationMessage = await validateProcessingAvailability() {
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

    func submitYouTubeImport(_ urlString: String) async -> String? {
        let result = await importYouTube(urlString: urlString)

        switch result {
        case .saved(let lecture):
            importFeedbackToken += 1
            pendingYouTubeImportLecture = lecture
            isYouTubeImportSheetPresented = false
            return nil
        case .rejected(let message):
            return message
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
            startProcessingIfNeeded(for: lecture)
            return .saved(lecture)
        } catch {
            lectures.removeAll { $0.id == lecture.id }
            let importName = textDocument.sourceType == .pdf ? "PDF" : "text"
            return .rejected(message: "Unable to save imported \(importName) right now.")
        }
    }

    func importYouTube(urlString: String) async -> SaveRecordingResult {
        let trimmedURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let sourceURL = URL(string: trimmedURLString), sourceURL.host() != nil else {
            return .rejected(message: "Enter a valid YouTube link.")
        }

        guard let videoID = importManager.parseYouTubeVideoID(from: sourceURL) else {
            return .rejected(message: "Enter a valid YouTube link.")
        }

        if let validationMessage = await validateProcessingAvailability() {
            return .rejected(message: validationMessage)
        }

        let lectureStatus: LectureStatus = if processingService == nil {
            .failed
        } else {
            .transcribing
        }
        let lecture = Lecture(
            id: UUID(),
            title: "YouTube Import",
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
            processingErrorMessage: processingService == nil ? "YouTube import requires backend processing." : nil
        )

        lectures.insert(lecture, at: 0)

        do {
            try await repository.saveLecture(lecture)
            startProcessingIfNeeded(for: lecture)
            return .saved(lecture)
        } catch {
            lectures.removeAll { $0.id == lecture.id }
            return .rejected(message: "Unable to save YouTube import right now.")
        }
    }

    func deleteLecture(_ lectureID: Lecture.ID) async -> DeleteLectureResult {
        guard lecture(withID: lectureID) != nil else {
            return .deleted
        }

        do {
            try await repository.deleteLecture(id: lectureID)
            lectures.removeAll { $0.id == lectureID }
            return .deleted
        } catch {
            return .rejected(message: "Unable to delete lecture right now.")
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
                presentImportError("No audio file was selected.")
                return
            }

            let importResult = await importAudio(from: url)
            handleImportResult(importResult)
        case .failure(let error):
            presentImportError("Import failed: \(error.localizedDescription)")
        }
    }

    func handlePDFImportResult(_ result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                presentImportError("No PDF file was selected.")
                return
            }

            processingStartFeedbackToken += 1
            let importResult = await importPDF(from: url)
            handleImportResult(importResult)
        case .failure(let error):
            presentImportError("Import failed: \(error.localizedDescription)")
        }
    }

    func load() async {
        startObservingRepositoryIfNeeded()
        isLoading = true
        await repository.start()
        await reloadRepositoryData()
        isLoading = false
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

        Task {
            var lectureToProcess = lecture

            do {
                lectureToProcess = try await processingService.startProcessing(for: lectureToProcess)
                replaceLecture(lectureToProcess)
            } catch {
                lectureToProcess.status = .failed
                lectureToProcess.processingErrorMessage = error.localizedDescription
                replaceLecture(lectureToProcess)
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
                await reloadRepositoryData()
            }
        }
    }

    private func reloadRepositoryData() async {
        async let fetchedFolders = repository.fetchFolders()
        async let fetchedLectures = repository.fetchLectures()

        folders = await fetchedFolders
        lectures = await fetchedLectures

        if hasActiveSearchQuery {
            await refreshSearchResults()
        } else {
            searchResults = []
        }

        if let selectedLectureID = selectedLecture?.id {
            selectedLecture = lectures.first(where: { $0.id == selectedLectureID })
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
    }
    
    private func handleImportResult(_ result: SaveRecordingResult) {
        switch result {
        case .saved(let lecture):
            importFeedbackToken += 1
            selectedLecture = lecture
        case .rejected(let message):
            presentImportError(message)
        }
    }

    private func presentImportError(_ message: String) {
        importAlertMessage = message
        isImportAlertPresented = true
    }

    private func present(_ action: LecturesListPendingConsentAction) {
        switch action {
        case .record:
            recorderViewModel = RecorderViewModel(limit: currentRecordingLimit)
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

    private func validateRecordingDuration(_ duration: Duration) async -> String? {
        let userProfile = await currentUserProfile()
        let limit = userProfile?.recordingLimitDuration ?? .seconds(5 * 60)
        guard duration <= limit else {
            return "Your \(userProfile?.plan.title ?? "Freemium") plan allows up to \(LectureFormatters.durationText(limit)) per recording."
        }

        return nil
    }

    private func validateAudioImportDuration(_ duration: Duration) async -> String? {
        let userProfile = await currentUserProfile()
        let limit = userProfile?.audioImportLimitDuration ?? .seconds(5 * 60)
        guard duration <= limit else {
            return "Your \(userProfile?.plan.title ?? "Freemium") plan allows audio imports up to \(LectureFormatters.durationText(limit)) per file."
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
            return "Your \(userProfile?.plan.title ?? "Freemium") plan allows PDF imports up to \(limit) pages per file."
        }

        return nil
    }

    private func validateProcessingAvailability() async -> String? {
        guard processingService != nil else {
            return nil
        }

        let userProfile = await currentUserProfile()
        guard userProfile?.canStartProcessing ?? true else {
            let remainingCount = max(userProfile?.processingQuota.remainingCount ?? 0, 0)
            return "You have \(remainingCount) processing attempts left on your \(userProfile?.plan.title ?? "Freemium") plan."
        }

        return nil
    }

    private func currentUserProfile() async -> AppUserProfile? {
        if let currentProfile = userProfileService?.currentProfile {
            return currentProfile
        }

        return try? await userProfileService?.ensureCurrentUserProfile()
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

enum LecturesListPendingConsentAction {
    case record
    case importAudio
    case importText
    case importPDF
    case importYouTube
}
