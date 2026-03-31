import Foundation
import SwiftUI

enum LectureStatus: String, CaseIterable, Identifiable, Codable {
    case draft
    case uploading
    case transcribing
    case generating
    case ready
    case failed

    var id: Self { self }

    var titleResource: LocalizedStringResource {
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

    var title: String {
        String(localized: titleResource)
    }
}

enum LectureSourceType: String, CaseIterable, Identifiable, Codable {
    case audio
    case text
    case pdf
    case youtube

    var id: Self { self }

    var titleResource: LocalizedStringResource {
        switch self {
        case .audio:
            "Audio Recording"
        case .text:
            "Text Import"
        case .pdf:
            "PDF Import"
        case .youtube:
            "YouTube Import"
        }
    }

    var title: String {
        String(localized: titleResource)
    }

    var processingStartStatus: LectureStatus {
        switch self {
        case .audio:
            .uploading
        case .text:
            .generating
        case .pdf:
            .generating
        case .youtube:
            .transcribing
        }
    }
}

enum LectureLocalizedTitleKey: String, CaseIterable {
    case newRecording = "New Recording"
    case importedRecording = "Imported Recording"
    case importedText = "Imported Text"
    case importedPDF = "Imported PDF"
    case youTubeImport = "YouTube Import"

    var resource: LocalizedStringResource {
        switch self {
        case .newRecording:
            "New Recording"
        case .importedRecording:
            "Imported Recording"
        case .importedText:
            "Imported Text"
        case .importedPDF:
            "Imported PDF"
        case .youTubeImport:
            "YouTube Import"
        }
    }

    fileprivate var localizedVariants: Set<String> {
        Self.cachedLocalizedVariants[self] ?? [rawValue]
    }

    fileprivate static func matching(_ title: String) -> Self? {
        allCases.first { $0.localizedVariants.contains(title) }
    }

    private static let cachedLocalizedVariants: [Self: Set<String>] = Dictionary(
        uniqueKeysWithValues: allCases.map { key in
            var variants: Set<String> = [key.rawValue]

            for localization in Bundle.main.localizations where localization != "Base" {
                variants.insert(
                    Bundle.main.localizedStringForLocale(
                        key.rawValue,
                        localeIdentifier: localization
                    )
                )
            }

            return (key, variants)
        }
    )
}

private extension Bundle {
    func localizedStringForLocale(_ key: String, localeIdentifier: String) -> String {
        let preferredLocalization = path(forResource: localeIdentifier, ofType: "lproj")
        let languageCode = localeIdentifier.split(separator: "-").first.map(String.init)
        let fallbackLocalization = languageCode.flatMap { path(forResource: $0, ofType: "lproj") }
        let bundlePath = preferredLocalization ?? fallbackLocalization
        let localizedBundle = bundlePath.flatMap(Bundle.init(path:))
        return localizedBundle?.localizedString(forKey: key, value: key, table: nil) ?? key
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
    var remoteAudioPath: String?
    var pdfPageCount: Int?
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
        remoteAudioPath: String? = nil,
        pdfPageCount: Int? = nil,
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
        self.remoteAudioPath = remoteAudioPath
        self.pdfPageCount = pdfPageCount
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

    var localizedDisplayTitleKey: LectureLocalizedTitleKey? {
        LectureLocalizedTitleKey.matching(title)
    }

    var displayTitle: String {
        guard let localizedDisplayTitleKey else {
            return title
        }

        return String(localized: localizedDisplayTitleKey.resource)
    }
}
