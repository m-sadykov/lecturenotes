import SwiftUI

/// Horizontal chips for the study note's sections; tapping one scrolls to it.
struct LectureSummaryOutlineView: View {
    let items: [MarkdownOutlineItem]
    let onSelect: (MarkdownOutlineItem) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    Button(item.title) {
                        onSelect(item)
                    }
                    .font(.subheadline)
                    .lineLimit(1)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(AppColor.accent)
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Sections"))
    }
}
