import SwiftUI

/// Visual content of a tile in the lecture detail action grid or the transcript row.
/// The caller wraps it in a `Button` or `NavigationLink`.
struct LectureDetailActionTile: View {
    enum Accessory {
        case checkmark
        case chevron
    }

    let content: LectureDetailContent
    let detailText: String?
    let accessory: Accessory

    var layout: Layout = .row

    enum Layout {
        /// Icon, title and accessory on one line. Used for the full-width transcript row.
        case row
        /// Icon and accessory on top, title below. Used in the two-column grid so titles
        /// keep their full width at large Dynamic Type sizes.
        case grid
    }

    var body: some View {
        Group {
            switch layout {
            case .row:
                HStack(spacing: 12) {
                    LectureDetailActionIcon(systemImage: content.systemImage)
                    LectureDetailActionTitle(title: content.titleResource, detailText: detailText)
                    Spacer(minLength: 0)
                    LectureDetailActionAccessory(accessory: accessory)
                }
            case .grid:
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        LectureDetailActionIcon(systemImage: content.systemImage)
                        Spacer(minLength: 0)
                        LectureDetailActionAccessory(accessory: accessory)
                    }
                    LectureDetailActionTitle(title: content.titleResource, detailText: detailText)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface)
        .clipShape(.rect(cornerRadius: 16))
        .contentShape(.rect(cornerRadius: 16))
    }
}

private struct LectureDetailActionIcon: View {
    let systemImage: String

    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 40

    var body: some View {
        Image(systemName: systemImage)
            .font(.body)
            .foregroundStyle(AppColor.accent)
            .frame(width: iconSize, height: iconSize)
            .background(AppColor.accent.opacity(0.14))
            .clipShape(.circle)
    }
}

private struct LectureDetailActionTitle: View {
    let title: LocalizedStringResource
    let detailText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.body)
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

private struct LectureDetailActionAccessory: View {
    let accessory: LectureDetailActionTile.Accessory

    var body: some View {
        switch accessory {
        case .checkmark:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppColor.accent)
                .accessibilityLabel(Text("Ready"))
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.footnote.bold())
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }
}
