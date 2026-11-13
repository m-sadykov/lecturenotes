import Foundation

/// A section heading that can be jumped to from an outline.
struct MarkdownOutlineItem: Hashable, Identifiable, Sendable {
    /// Index of the heading in the parsed block list. Also used as the scroll anchor.
    let blockIndex: Int
    /// Heading text with inline Markdown markers removed.
    let title: String

    var id: Int { blockIndex }
}

nonisolated enum MarkdownOutline {
    /// Level-2 headings (`##`) of the document: the sections of a study note.
    static func items(in blocks: [MarkdownBlock]) -> [MarkdownOutlineItem] {
        blocks.indices.compactMap { index in
            guard case .heading(let level, let text) = blocks[index], level == 2 else {
                return nil
            }
            return MarkdownOutlineItem(blockIndex: index, title: plainText(from: text))
        }
    }

    /// Scroll anchor attached to the heading view at `blockIndex`.
    static func anchor(for blockIndex: Int) -> String {
        "markdown-heading-\(blockIndex)"
    }

    private static func plainText(from markdown: String) -> String {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        guard let attributed = try? AttributedString(markdown: markdown, options: options) else {
            return markdown
        }
        return String(attributed.characters)
    }
}
