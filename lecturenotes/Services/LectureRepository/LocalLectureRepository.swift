import Foundation

@MainActor
final class LocalLectureRepository: LectureRepository {
    private struct Store: Codable {
        var lectures: [StoredLecture] = []
        var folders: [LectureFolder] = []
    }

    private struct StoredLecture: Codable {
        let id: UUID
        var title: String
        var audioFileName: String?
        var folderID: LectureFolder.ID?
        var createdAt: Date
        var durationSeconds: Double
        var status: LectureStatus
        var transcript: String
        var summaryShort: String
        var summaryLong: String
        var flashcards: [Flashcard]
        var quiz: [QuizQuestion]
        var processingErrorMessage: String?

        init(lecture: Lecture, recordingsDirectory: URL) {
            id = lecture.id
            title = lecture.title
            audioFileName = lecture.audioURL.flatMap { url in
                if url.deletingLastPathComponent() == recordingsDirectory {
                    return url.lastPathComponent
                }
                return url.lastPathComponent
            }
            folderID = lecture.folderID
            createdAt = lecture.createdAt
            durationSeconds = lecture.duration.timeInterval
            status = lecture.status
            transcript = lecture.transcript
            summaryShort = lecture.summaryShort
            summaryLong = lecture.summaryLong
            flashcards = lecture.flashcards
            quiz = lecture.quiz
            processingErrorMessage = lecture.processingErrorMessage
        }

        func lecture(recordingsDirectory: URL) -> Lecture {
            Lecture(
                id: id,
                title: title,
                audioURL: audioFileName.map { recordingsDirectory.appending(path: $0) },
                folderID: folderID,
                createdAt: createdAt,
                duration: .seconds(durationSeconds),
                status: status,
                transcript: transcript,
                summaryShort: summaryShort,
                summaryLong: summaryLong,
                flashcards: flashcards,
                quiz: quiz,
                processingErrorMessage: processingErrorMessage
            )
        }
    }

    enum RepositoryError: LocalizedError {
        case failedToCreateStorage

        var errorDescription: String? {
            switch self {
            case .failedToCreateStorage:
                "Unable to prepare local lecture storage."
            }
        }
    }

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func fetchLectures() async -> [Lecture] {
        let store = loadStore()
        return store.lectures
            .map { $0.lecture(recordingsDirectory: recordingsDirectory) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func fetchFolders() async -> [LectureFolder] {
        loadStore().folders
    }

    func fetchLecture(id: UUID) async -> Lecture? {
        loadStore().lectures
            .first(where: { $0.id == id })?
            .lecture(recordingsDirectory: recordingsDirectory)
    }

    func saveLecture(_ lecture: Lecture) async throws {
        try ensureStorageExists()
        var store = loadStore()
        let storedLecture = StoredLecture(lecture: lecture, recordingsDirectory: recordingsDirectory)

        if let index = store.lectures.firstIndex(where: { $0.id == lecture.id }) {
            store.lectures[index] = storedLecture
        } else {
            store.lectures.append(storedLecture)
        }

        try saveStore(store)
    }

    func saveFolders(_ folders: [LectureFolder]) async throws {
        try ensureStorageExists()
        var store = loadStore()
        store.folders = folders
        try saveStore(store)
    }

    func deleteLecture(id: UUID) async throws {
        var store = loadStore()
        let deletedLecture = store.lectures.first(where: { $0.id == id })
        store.lectures.removeAll { $0.id == id }
        try saveStore(store)

        if let audioFileName = deletedLecture?.audioFileName {
            let audioURL = recordingsDirectory.appending(path: audioFileName)
            try? fileManager.removeItem(at: audioURL)
        }
    }

    private var storeURL: URL {
        URL.documentsDirectory.appending(path: "lectures-store.json")
    }

    private var recordingsDirectory: URL {
        URL.documentsDirectory.appending(path: "Recordings", directoryHint: .isDirectory)
    }

    private func ensureStorageExists() throws {
        do {
            try fileManager.createDirectory(
                at: recordingsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw RepositoryError.failedToCreateStorage
        }
    }

    private func loadStore() -> Store {
        do {
            try ensureStorageExists()
            guard fileManager.fileExists(atPath: storeURL.path(percentEncoded: false)) else {
                return Store()
            }

            let data = try Data(contentsOf: storeURL)
            return try decoder.decode(Store.self, from: data)
        } catch {
            return Store()
        }
    }

    private func saveStore(_ store: Store) throws {
        let data = try encoder.encode(store)
        try data.write(to: storeURL, options: [.atomic])
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        TimeInterval(components.seconds) + (TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000)
    }
}
