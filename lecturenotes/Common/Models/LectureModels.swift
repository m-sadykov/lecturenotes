import Foundation

enum LectureStatus: String, CaseIterable, Identifiable, Codable {
    case draft
    case uploading
    case transcribing
    case generating
    case ready
    case failed

    var id: Self { self }

    var title: String {
        switch self {
        case .draft:
            "Draft"
        case .uploading:
            "Uploading"
        case .transcribing:
            "Transcribing"
        case .generating:
            "Generating"
        case .ready:
            "Ready"
        case .failed:
            "Failed"
        }
    }
}

enum LectureSourceType: String, CaseIterable, Identifiable, Codable {
    case audio
    case text
    case youtube

    var id: Self { self }

    var title: String {
        switch self {
        case .audio:
            "Audio Recording"
        case .text:
            "Text Import"
        case .youtube:
            "YouTube Import"
        }
    }

    var processingStartStatus: LectureStatus {
        switch self {
        case .audio:
            .uploading
        case .text:
            .generating
        case .youtube:
            .transcribing
        }
    }
}

struct Flashcard: Identifiable, Hashable, Codable {
    let id: UUID
    var question: String
    var answer: String

    init(id: UUID = UUID(), question: String, answer: String) {
        self.id = id
        self.question = question
        self.answer = answer
    }
}

struct QuizQuestion: Identifiable, Hashable, Codable {
    let id: UUID
    var question: String
    var options: [String]
    var correctIndex: Int

    init(id: UUID = UUID(), question: String, options: [String], correctIndex: Int) {
        self.id = id
        self.question = question
        self.options = options
        self.correctIndex = correctIndex
    }
}

struct LectureFolder: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

struct Lecture: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var sourceType: LectureSourceType
    var audioURL: URL?
    var sourceURL: URL?
    var youtubeVideoID: String?
    var folderID: LectureFolder.ID?
    var createdAt: Date
    var duration: Duration
    var status: LectureStatus
    var transcript: String
    var summaryShort: String
    var summaryLong: String
    var flashcards: [Flashcard]
    var quiz: [QuizQuestion]
    var processingErrorMessage: String?

    init(
        id: UUID = UUID(),
        title: String,
        sourceType: LectureSourceType = .audio,
        audioURL: URL? = nil,
        sourceURL: URL? = nil,
        youtubeVideoID: String? = nil,
        folderID: LectureFolder.ID? = nil,
        createdAt: Date,
        duration: Duration,
        status: LectureStatus,
        transcript: String,
        summaryShort: String,
        summaryLong: String,
        flashcards: [Flashcard],
        quiz: [QuizQuestion],
        processingErrorMessage: String? = nil
    ) {
        self.id = id
        self.title = title
        self.sourceType = sourceType
        self.audioURL = audioURL
        self.sourceURL = sourceURL
        self.youtubeVideoID = youtubeVideoID
        self.folderID = folderID
        self.createdAt = createdAt
        self.duration = duration
        self.status = status
        self.transcript = transcript
        self.summaryShort = summaryShort
        self.summaryLong = summaryLong
        self.flashcards = flashcards
        self.quiz = quiz
        self.processingErrorMessage = processingErrorMessage
    }

    var processingStartStatus: LectureStatus {
        if sourceType == .youtube, !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .generating
        }

        return sourceType.processingStartStatus
    }
}
