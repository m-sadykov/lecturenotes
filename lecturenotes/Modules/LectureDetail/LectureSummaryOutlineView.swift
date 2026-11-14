import SwiftUI

/// Horizontal chips for the study note's sections; tapping one scrolls to it.
struct LectureSummaryOutlineView: View {
    let items: [MarkdownOutlineItem]
    let onSelect: (MarkdownOutlineItem) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    // White capsule on the canvas, matching the home screen's folder chips.
                    Button {
                        onSelect(item)
                    } label: {
                        Text(item.title)
                            .font(.subheadline)
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppColor.surface, in: .capsule)
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Sections"))
    }
}
