import Foundation
import PDFKit

struct LecturePDFTextExtractor {
    struct ExtractionResult {
        let text: String
        let suggestedTitle: String
        let createdAt: Date
    }

    enum ExtractionError: LocalizedError {
        case unreadableDocument
        case emptyDocument

        var errorDescription: String? {
            switch self {
            case .unreadableDocument:
                "Unable to read this PDF file."
            case .emptyDocument:
                "This PDF does not contain selectable text."
            }
        }
    }

    func extractText(from sourceURL: URL) async throws -> ExtractionResult {
        let didAccessSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScope {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let resourceValues = try? sourceURL.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
        let createdAt = resourceValues?.contentModificationDate ?? resourceValues?.creationDate ?? .now
        let fallbackTitle = sourceURL.deletingPathExtension().lastPathComponent

        return try await Task.detached(priority: .userInitiated) {
            guard let document = PDFDocument(url: sourceURL) else {
                throw ExtractionError.unreadableDocument
            }

            let extractedText = (0..<document.pageCount)
                .compactMap { document.page(at: $0)?.string?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n")
                .replacing("\r\n", with: "\n")
                .replacing("\r", with: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !extractedText.isEmpty else {
                throw ExtractionError.emptyDocument
            }

            let metadataTitle = (document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let suggestedTitle = if let metadataTitle, !metadataTitle.isEmpty {
                metadataTitle
            } else if !fallbackTitle.isEmpty {
                fallbackTitle
            } else {
                "Imported PDF"
            }

            return ExtractionResult(
                text: extractedText,
                suggestedTitle: suggestedTitle,
                createdAt: createdAt
            )
        }.value
    }
}
