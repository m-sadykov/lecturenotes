import AVFoundation
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

    var lectures: [Lecture] = []
    var folders: [LectureFolder] = []
    var searchText = ""
    var selectedFolderID: LectureFolder.ID?
    var isLoading = false

    init(
        repository: LectureRepository,
        processingService: FirebaseLectureProcessingService? = nil
    ) {
        self.repository = repository
        self.processingService = processingService
    }

    var filteredLectures: [Lecture] {
        lectures.filter { lecture in
            let matchesFolder = selectedFolderID == nil || lecture.folderID == selectedFolderID
            let matchesQuery =
                searchText.isEmpty ||
                lecture.title.localizedStandardContains(searchText)
            return matchesFolder && matchesQuery
        }
    }

    func lecture(withID lectureID: Lecture.ID) -> Lecture? {
        lectures.first(where: { $0.id == lectureID })
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

        let lectureStatus: LectureStatus = processingService == nil ? .ready : .uploading
        let lecture = Lecture(
            title: "New Recording",
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

    func importAudio(from sourceURL: URL) async -> SaveRecordingResult {
        let lectureID = UUID()

        do {
            let importedAudio = try await importAudioFile(from: sourceURL, lectureID: lectureID)
            let lectureStatus: LectureStatus = processingService == nil ? .ready : .uploading
            let lecture = Lecture(
                id: lectureID,
                title: importedAudio.suggestedTitle,
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

    func deleteLecture(_ lectureID: Lecture.ID) async -> DeleteLectureResult {
        guard let lecture = lecture(withID: lectureID) else {
            return .deleted
        }

        do {
            if let processingService {
                try await processingService.deleteLecture(lecture)
            }

            try await repository.deleteLecture(id: lectureID)
            lectures.removeAll { $0.id == lectureID }
            return .deleted
        } catch {
            return .rejected(message: "Unable to delete recording right now.")
        }
    }

    func load() async {
        isLoading = true
        folders = await repository.fetchFolders()
        lectures = await repository.fetchLectures()
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
            } catch {
                lectureToProcess.status = .failed
                lectureToProcess.processingErrorMessage = "Unable to start processing right now."
            }

            replaceLecture(lectureToProcess)
            try? await repository.saveLecture(lectureToProcess)
        }
    }

    private func importAudioFile(from sourceURL: URL, lectureID: UUID) async throws -> ImportedAudio {
        let didAccessSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScope {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileManager = FileManager.default
        let recordingsDirectory = URL.documentsDirectory.appending(path: "Recordings", directoryHint: .isDirectory)
        try fileManager.createDirectory(
            at: recordingsDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let pathExtension = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension.lowercased()
        let destinationURL = recordingsDirectory
            .appending(path: lectureID.uuidString)
            .appendingPathExtension(pathExtension)

        if fileManager.fileExists(atPath: destinationURL.path(percentEncoded: false)) {
            try fileManager.removeItem(at: destinationURL)
        }

        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            throw ImportError.unableToImportAudio
        }

        let resourceValues = try? sourceURL.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
        let createdAt = resourceValues?.contentModificationDate ?? resourceValues?.creationDate ?? .now
        let duration = await loadDuration(for: destinationURL) ?? .seconds(1)
        let suggestedTitle = sourceURL.deletingPathExtension().lastPathComponent

        return ImportedAudio(
            localURL: destinationURL,
            createdAt: createdAt,
            duration: duration,
            suggestedTitle: suggestedTitle.isEmpty ? "Imported Recording" : suggestedTitle
        )
    }

    private func loadDuration(for audioURL: URL) async -> Duration? {
        let asset = AVURLAsset(url: audioURL)

        do {
            let duration = try await asset.load(.duration)
            let seconds = duration.seconds
            guard seconds.isFinite, seconds > 0 else {
                return nil
            }
            return .seconds(seconds)
        } catch {
            return nil
        }
    }
}

private struct ImportedAudio {
    let localURL: URL
    let createdAt: Date
    let duration: Duration
    let suggestedTitle: String
}

private enum ImportError: LocalizedError {
    case unableToImportAudio

    var errorDescription: String? {
        switch self {
        case .unableToImportAudio:
            "Unable to import this audio file."
        }
    }
}
