import SwiftUI

/// Renders the Markdown subset described by `MarkdownBlock` as native SwiftUI text.
///
/// Each heading carries the id `MarkdownOutline.anchor(for:)`, so a surrounding
/// `ScrollViewReader` can scroll to items from `MarkdownOutline.items(in:)`.
struct MarkdownContentView: View {
    private let blocks: [MarkdownBlock]

    init(markdown: String) {
        blocks = MarkdownBlockParser.parse(markdown)
    }

    init(blocks: [MarkdownBlock]) {
        self.blocks = blocks
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(blocks.indices, id: \.self) { index in
                MarkdownBlockView(block: blocks[index])
                    .padding(.top, topSpacing(before: blocks[index], at: index))
                    .id(MarkdownOutline.anchor(for: index))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    /// Adds air above section headings so sections read as separate groups.
    private func topSpacing(before block: MarkdownBlock, at index: Int) -> CGFloat {
        guard index > 0, case .heading(let level, _) = block, level >= 2 else {
            return 0
        }
        return 12
    }
}

private struct MarkdownBlockView: View {
    let block: MarkdownBlock

    @ScaledMetric(relativeTo: .body) private var indentStep: CGFloat = 18

    var body: some View {
        switch block {
        case .heading(let level, let text):
            MarkdownInlineText(text)
                .font(headingFont(level))
                .bold()
                .foregroundStyle(AppColor.accent)
                .accessibilityAddTraits(.isHeader)

        case .paragraph(let text):
            MarkdownInlineText(text)
                .font(.body)
                .lineSpacing(4)

        case .listItem(let marker, let indentLevel, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                MarkdownListMarkerView(marker: marker, indentLevel: indentLevel)
                MarkdownInlineText(text)
                    .font(.body)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, CGFloat(indentLevel) * indentStep)

        case .divider:
            Divider()
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .title2
        case 2: .title3
        default: .headline
        }
    }
}

private struct MarkdownListMarkerView: View {
    let marker: MarkdownBlock.ListMarker
    let indentLevel: Int

    var body: some View {
        switch marker {
        case .bullet:
            Text(indentLevel == 0 ? "•" : "◦")
                .foregroundStyle(.secondary)
        case .number(let number):
            Text("\(number).")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

/// A `Text` that interprets inline Markdown (`**bold**`, `*italic*`) and falls back
/// to the raw string if parsing fails.
private struct MarkdownInlineText: View {
    private let attributed: AttributedString

    init(_ markdown: String) {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        attributed = (try? AttributedString(markdown: markdown, options: options))
            ?? AttributedString(markdown)
    }

    var body: some View {
        Text(attributed)
    }
}

#Preview {
    ScrollView {
        MarkdownContentView(
            markdown: """
            # The Literature of C.S. Lewis — Lecture 1
            ---
            This lecture introduces **C.S. Lewis's** reputation and the central idea of **joy**.

            ## Course and Professor
            - The course focuses on Lewis's *fiction* and **Christian apologetics**.
              - Taught by **Timothy Shutt** at Kenyon College.
            - Lectures cover the Narnia series.

            ## Key Steps
            1. Read the assigned chapters.
            2. Review the flashcards.
            """
        )
        .padding()
    }
}
