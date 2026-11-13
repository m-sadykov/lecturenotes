import Foundation

/// Splits Markdown text into `MarkdownBlock`s.
///
/// Supports the subset the backend is asked to produce: headings, bullet and numbered
/// lists (nested by indentation), horizontal rules and paragraphs. Anything else is
/// treated as paragraph text, so older plain-text summaries render as paragraphs.
nonisolated enum MarkdownBlockParser {
    /// Number of leading spaces that make one nesting level. A tab counts as one level.
    private static let spacesPerIndentLevel = 2

    static func parse(_ markdown: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraphLines: [String] = []

        // Single line breaks are kept (not re-flowed as strict Markdown would) because
        // summaries generated before the Markdown prompt use them as paragraph breaks.
        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            blocks.append(.paragraph(text: paragraphLines.joined(separator: "\n")))
            paragraphLines.removeAll()
        }

        for rawLine in markdown.replacing("\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                flushParagraph()
                continue
            }

            if isDivider(trimmed) {
                flushParagraph()
                blocks.append(.divider)
                continue
            }

            if let heading = heading(from: trimmed) {
                flushParagraph()
                blocks.append(heading)
                continue
            }

            if let listItem = listItem(from: line) {
                flushParagraph()
                blocks.append(listItem)
                continue
            }

            paragraphLines.append(trimmed)
        }

        flushParagraph()
        return blocks
    }

    private static func isDivider(_ line: String) -> Bool {
        let compact = line.replacing(" ", with: "")
        guard compact.count >= 3, let first = compact.first, "-*_".contains(first) else {
            return false
        }
        return compact.allSatisfy { $0 == first }
    }

    private static func heading(from line: String) -> MarkdownBlock? {
        let hashes = line.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes) else { return nil }

        let remainder = line.dropFirst(hashes)
        guard remainder.first == " " else { return nil }

        let text = remainder.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }

        return .heading(level: min(hashes, 3), text: text)
    }

    private static func listItem(from line: String) -> MarkdownBlock? {
        let indentWidth = line.prefix { $0 == " " || $0 == "\t" }.reduce(0) { width, character in
            width + (character == "\t" ? spacesPerIndentLevel : 1)
        }
        let content = line.drop { $0 == " " || $0 == "\t" }

        if let first = content.first, "-*•".contains(first), content.dropFirst().first == " " {
            let text = content.dropFirst(2).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return nil }
            return .listItem(marker: .bullet, indentLevel: indentWidth / spacesPerIndentLevel, text: text)
        }

        let digits = content.prefix { $0.isASCII && $0.isNumber }
        if !digits.isEmpty, digits.count <= 3, let number = Int(digits) {
            let afterDigits = content.dropFirst(digits.count)
            if let delimiter = afterDigits.first, ".)".contains(delimiter), afterDigits.dropFirst().first == " " {
                let text = afterDigits.dropFirst(2).trimmingCharacters(in: .whitespaces)
                guard !text.isEmpty else { return nil }
                return .listItem(marker: .number(number), indentLevel: indentWidth / spacesPerIndentLevel, text: text)
            }
        }

        return nil
    }
}
