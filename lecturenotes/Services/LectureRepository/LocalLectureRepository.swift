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
        var sourceType: LectureSourceType
        var audioFileName: String?
        var pdfPageCount: Int?
        var sourceURL: URL?
        var youtubeVideoID: String?
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

        private enum CodingKeys: String, CodingKey {
            case id
            case title
            case sourceType
            case audioFileName
            case pdfPageCount
            case sourceURL
            case youtubeVideoID
            case folderID
            case createdAt
            case durationSeconds
            case status
            case transcript
            case summaryShort
            case summaryLong
            case flashcards
            case quiz
            case processingErrorMessage
        }

        init(lecture: Lecture, recordingsDirectory: URL) {
            id = lecture.id
            title = lecture.title
            sourceType = lecture.sourceType
            audioFileName = lecture.audioURL.flatMap { url in
                if url.deletingLastPathComponent() == recordingsDirectory {
                    return url.lastPathComponent
                }
                return url.lastPathComponent
            }
            pdfPageCount = lecture.pdfPageCount
            sourceURL = lecture.sourceURL
            youtubeVideoID = lecture.youtubeVideoID
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

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            title = try container.decode(String.self, forKey: .title)
            sourceType = try container.decodeIfPresent(LectureSourceType.self, forKey: .sourceType) ?? .audio
            audioFileName = try container.decodeIfPresent(String.self, forKey: .audioFileName)
            pdfPageCount = try container.decodeIfPresent(Int.self, forKey: .pdfPageCount)
            sourceURL = try container.decodeIfPresent(URL.self, forKey: .sourceURL)
            youtubeVideoID = try container.decodeIfPresent(String.self, forKey: .youtubeVideoID)
            folderID = try container.decodeIfPresent(LectureFolder.ID.self, forKey: .folderID)
            createdAt = try container.decode(Date.self, forKey: .createdAt)
            durationSeconds = try container.decode(Double.self, forKey: .durationSeconds)
            status = try container.decode(LectureStatus.self, forKey: .status)
            transcript = try container.decode(String.self, forKey: .transcript)
            summaryShort = try container.decode(String.self, forKey: .summaryShort)
            summaryLong = try container.decode(String.self, forKey: .summaryLong)
            flashcards = try container.decode([Flashcard].self, forKey: .flashcards)
            quiz = try container.decode([QuizQuestion].self, forKey: .quiz)
            processingErrorMessage = try container.decodeIfPresent(String.self, forKey: .processingErrorMessage)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(title, forKey: .title)
            try container.encode(sourceType, forKey: .sourceType)
            try container.encodeIfPresent(audioFileName, forKey: .audioFileName)
            try container.encodeIfPresent(pdfPageCount, forKey: .pdfPageCount)
            try container.encodeIfPresent(sourceURL, forKey: .sourceURL)
            try container.encodeIfPresent(youtubeVideoID, forKey: .youtubeVideoID)
            try container.encodeIfPresent(folderID, forKey: .folderID)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encode(durationSeconds, forKey: .durationSeconds)
            try container.encode(status, forKey: .status)
            try container.encode(transcript, forKey: .transcript)
            try container.encode(summaryShort, forKey: .summaryShort)
            try container.encode(summaryLong, forKey: .summaryLong)
            try container.encode(flashcards, forKey: .flashcards)
            try container.encode(quiz, forKey: .quiz)
            try container.encodeIfPresent(processingErrorMessage, forKey: .processingErrorMessage)
        }

        func lecture(recordingsDirectory: URL) -> Lecture {
            Lecture(
                id: id,
                title: title,
                sourceType: sourceType,
                audioURL: audioFileName.map { recordingsDirectory.appending(path: $0) },
                pdfPageCount: pdfPageCount,
                sourceURL: sourceURL,
                youtubeVideoID: youtubeVideoID,
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
                String(localized: "Unable to prepare local lecture storage.")
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
