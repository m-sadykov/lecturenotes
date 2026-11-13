import SwiftUI

/// "Open transcript" row plus the grid of study tools (flashcards, quiz, key points).
/// Every tile calls `onOpen`; the view model decides whether to push or present.
struct LectureDetailActionsGridView: View {
    let lecture: Lecture
    let onOpen: (LectureDetailContent) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 12) {
            if LectureDetailContent.transcript.isAvailable(for: lecture) {
                Button {
                    onOpen(.transcript)
                } label: {
                    LectureDetailActionTile(content: .transcript, detailText: nil, accessory: .chevron)
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(gridContent, id: \.self) { content in
                    Button {
                        onOpen(content)
                    } label: {
                        LectureDetailActionTile(
                            content: content,
                            detailText: content.detailText(for: lecture),
                            accessory: content == .keyPoints ? .chevron : .checkmark,
                            layout: .grid
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var gridContent: [LectureDetailContent] {
        [.flashcards, .quiz, .keyPoints].filter { $0.isAvailable(for: lecture) }
    }
}
