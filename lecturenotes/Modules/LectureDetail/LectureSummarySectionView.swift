import SwiftUI

/// The generated study note: optional "In short" callout, section outline and the
/// Markdown body, with copy and share actions.
struct LectureSummarySectionView: View {
    let summaryText: String
    let briefText: String?
    let onCopy: () -> Void
    let onSelectSection: (MarkdownOutlineItem) -> Void

    private let blocks: [MarkdownBlock]
    private let outlineItems: [MarkdownOutlineItem]

    /// The outline only helps when there is more than one section to jump between.
    private static let minimumOutlineItems = 2

    init(
        summaryText: String,
        briefText: String?,
        onCopy: @escaping () -> Void,
        onSelectSection: @escaping (MarkdownOutlineItem) -> Void
    ) {
        self.summaryText = summaryText
        self.briefText = briefText
        self.onCopy = onCopy
        self.onSelectSection = onSelectSection
        blocks = MarkdownBlockParser.parse(summaryText)
        outlineItems = MarkdownOutline.items(in: blocks)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(LectureDetailContent.summary.titleResource)
                    .font(.title3)
                    .bold()
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                if !blocks.isEmpty {
                    HStack(spacing: 20) {
                        Button("Copy", systemImage: "doc.on.doc", action: onCopy)

                        ShareLink(item: summaryText) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .foregroundStyle(AppColor.accent)
                }
            }

            if let briefText {
                LectureSummaryBriefView(text: briefText)
            }

            if outlineItems.count >= Self.minimumOutlineItems {
                LectureSummaryOutlineView(items: outlineItems, onSelect: onSelectSection)
            }

            if blocks.isEmpty {
                Text("No detailed summary yet.")
                    .foregroundStyle(.secondary)
            } else {
                MarkdownContentView(blocks: blocks)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
