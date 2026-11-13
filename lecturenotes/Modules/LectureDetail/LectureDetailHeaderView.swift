import SwiftUI

/// Title, metadata and folder chip at the top of the lecture detail screen.
/// The chip appears only when the lecture is in a folder; adding to a folder lives in
/// the actions menu, so the header does not repeat it.
struct LectureDetailHeaderView: View {
    let lecture: Lecture
    let folderName: String?
    var showsFolderChip = true
    let onFolderTap: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LectureDetailTitleText(lecture: lecture)
                .font(.title)
                .bold()
                .lineLimit(3)

            if showsFolderChip, let folderName {
                // Chip and metadata share one row, with the metadata wrapping to a second
                // line if needed. At accessibility text sizes they stack instead.
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 10) {
                        LectureDetailMetadataText(lecture: lecture)
                        LectureDetailFolderChip(folderName: folderName, action: onFolderTap)
                    }
                } else {
                    HStack(spacing: 12) {
                        LectureDetailFolderChip(folderName: folderName, action: onFolderTap)
                            .fixedSize()
                        LectureDetailMetadataText(lecture: lecture)
                    }
                }
            } else {
                LectureDetailMetadataText(lecture: lecture)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Shows the lecture's folder; tapping it opens the folder picker to move the lecture.
private struct LectureDetailFolderChip: View {
    let folderName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(folderName)
            } icon: {
                Image(systemName: "folder")
            }
            .font(.subheadline)
            .lineLimit(1)
            .foregroundStyle(.primary)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(AppColor.fillSubtle, in: .capsule)
        }
        .buttonStyle(.plain)
    }
}

private struct LectureDetailTitleText: View {
    let lecture: Lecture

    var body: some View {
        if let localizedDisplayTitleKey = lecture.localizedDisplayTitleKey {
            Text(localizedDisplayTitleKey.resource)
        } else {
            Text(lecture.title)
        }
    }
}

private struct LectureDetailMetadataText: View {
    let lecture: Lecture

    var body: some View {
        metadata
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(2)
    }

    private var metadata: Text {
        if lecture.sourceType == .audio {
            Text(lecture.createdAt, format: LectureFormatters.date)
            + Text(" · ")
            + Text(LectureFormatters.clockText(lecture.duration))
            + Text(" · ")
            + Text(lecture.sourceType.titleResource)
        } else {
            Text(lecture.createdAt, format: LectureFormatters.date)
            + Text(" · ")
            + Text(lecture.sourceType.titleResource)
        }
    }
}
