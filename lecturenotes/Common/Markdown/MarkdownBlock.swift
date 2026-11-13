import Foundation

/// A block-level element of the Markdown subset produced by the study-pack backend.
///
/// Inline formatting (`**bold**`, `*italic*`) stays inside `text` and is rendered by
/// `AttributedString(markdown:)` at display time.
enum MarkdownBlock: Hashable, Sendable {
    /// `#`, `##`, `###` heading. `level` is 1...3.
    case heading(level: Int, text: String)
    /// A paragraph of one or more joined lines.
    case paragraph(text: String)
    /// A bullet (`-`, `*`, `•`) or numbered (`1.`) list item. `indentLevel` starts at 0.
    case listItem(marker: ListMarker, indentLevel: Int, text: String)
    /// `---`, `***` or `___` on its own line.
    case divider

    enum ListMarker: Hashable, Sendable {
        case bullet
        case number(Int)
    }
}
