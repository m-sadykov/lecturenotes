import AVFoundation
import Foundation

struct LectureImportManager {
    struct ImportedAudio {
        let localURL: URL
        let createdAt: Date
        let duration: Duration
        let suggestedTitle: String
    }

    struct ImportedTextDocument {
        let text: String
        let suggestedTitle: String
        let createdAt: Date
        let sourceType: LectureSourceType
        let pageCount: Int?
    }

    enum ImportError: LocalizedError {
        case unableToImportAudio
        case missingAudioDuration

        var errorDescription: String? {
            switch self {
            case .unableToImportAudio:
                String(localized: "Unable to import this audio file.")
            case .missingAudioDuration:
                String(localized: "Unable to read the audio duration from file metadata.")
            }
        }
    }

    private let pdfTextExtractor: LecturePDFTextExtractor

    init(pdfTextExtractor: LecturePDFTextExtractor = LecturePDFTextExtractor()) {
        self.pdfTextExtractor = pdfTextExtractor
    }

    func importAudio(from sourceURL: URL, lectureID: UUID) async throws -> ImportedAudio {
        let didAccessSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScope {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let duration = await loadDuration(for: sourceURL) else {
            throw ImportError.missingAudioDuration
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
        let suggestedTitle = sourceURL.deletingPathExtension().lastPathComponent

        return ImportedAudio(
            localURL: destinationURL,
            createdAt: createdAt,
            duration: duration,
            suggestedTitle: suggestedTitle.isEmpty ? LectureLocalizedTitleKey.importedRecording.rawValue : suggestedTitle
        )
    }

    func importPDF(from sourceURL: URL) async throws -> ImportedTextDocument {
        let extractedPDF = try await pdfTextExtractor.extractText(from: sourceURL)
        return ImportedTextDocument(
            text: extractedPDF.text,
            suggestedTitle: extractedPDF.suggestedTitle,
            createdAt: extractedPDF.createdAt,
            sourceType: .pdf,
            pageCount: extractedPDF.pageCount
        )
    }

    func makeTextDocument(from text: String) -> ImportedTextDocument {
        ImportedTextDocument(
            text: text,
            suggestedTitle: suggestedTitle(for: text),
            createdAt: .now,
            sourceType: .text,
            pageCount: nil
        )
    }

    func parseYouTubeVideoID(from url: URL) -> String? {
        let host = url.host()?.lowercased() ?? ""

        if host.contains("youtu.be") {
            let candidate = url.pathComponents.dropFirst().first ?? ""
            return candidate.count == 11 ? candidate : nil
        }

        if host.contains("youtube.com") {
            if let queryVideoID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "v" })?
                .value,
               queryVideoID.count == 11 {
                return queryVideoID
            }

            let pathComponents = url.pathComponents.filter { $0 != "/" }
            if let embeddedVideoID = pathComponents.last,
               ["embed", "shorts", "live"].contains(pathComponents.dropLast().last ?? ""),
               embeddedVideoID.count == 11 {
                return embeddedVideoID
            }
        }

        return nil
    }

    func estimateReadingDuration(for text: String) -> Duration {
        let wordCount = text.split(whereSeparator: \.isWhitespace).count
        let seconds = max(Double(wordCount) / 3, 30)
        return .seconds(seconds)
    }

    func suggestedTitle(for text: String) -> String {
        let firstLine = text
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })

        let candidate = firstLine ?? text
        let words = candidate.split(whereSeparator: \.isWhitespace)
        let title = words.prefix(6).joined(separator: " ")
        return title.isEmpty ? LectureLocalizedTitleKey.importedText.rawValue : title
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
