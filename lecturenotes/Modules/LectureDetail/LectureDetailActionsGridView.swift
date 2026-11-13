import SwiftUI

/// Two-column grid of study tools: transcript, flashcards, quiz and key points.
/// Every tile calls `onOpen`; the view model decides whether to push or present.
/// At accessibility text sizes the tiles stack in one column so titles stay readable.
struct LectureDetailActionsGridView: View {
    let lecture: Lecture
    let onOpen: (LectureDetailContent) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let tools = LectureDetailContent.studyTools(for: lecture)
        let columnCount = dynamicTypeSize.isAccessibilitySize ? 1 : 2

        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            ForEach(tools.chunked(into: columnCount), id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { content in
                        Button {
                            onOpen(content)
                        } label: {
                            LectureDetailActionTile(
                                content: content,
                                detailText: content.detailText(for: lecture)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private extension Array {
    /// Splits the array into consecutive slices of at most `size` elements.
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { start in
            Array(self[start..<Swift.min(start + size, count)])
        }
    }
}
