import SwiftUI

/// Compact tile in the lecture detail study-tools grid: icon, title with an optional
/// status line such as "10 cards", and a chevron. The caller wraps it in a `Button`.
struct LectureDetailActionTile: View {
    let content: LectureDetailContent
    let detailText: String?

    var body: some View {
        HStack(spacing: 10) {
            LectureDetailActionIcon(systemImage: content.systemImage)
            LectureDetailActionTitle(title: content.titleResource, detailText: detailText)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(AppColor.fillSubtle)
        .clipShape(.rect(cornerRadius: 16))
        .contentShape(.rect(cornerRadius: 16))
    }
}

private struct LectureDetailActionIcon: View {
    let systemImage: String

    @ScaledMetric(relativeTo: .subheadline) private var iconSize: CGFloat = 32

    var body: some View {
        Image(systemName: systemImage)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .frame(width: iconSize, height: iconSize)
            .background(AppColor.fillSubtle)
            .clipShape(.circle)
    }
}

private struct LectureDetailActionTitle: View {
    let title: LocalizedStringResource
    let detailText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)

            if let detailText {
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    HStack {
        LectureDetailActionTile(content: .flashcards, detailText: "10 cards")
        LectureDetailActionTile(content: .keyPoints, detailText: nil)
    }
    .fixedSize(horizontal: false, vertical: true)
    .padding()
}
