import SwiftUI

/// Title, metadata and folder button at the top of the lecture detail screen.
struct LectureDetailHeaderView: View {
    let lecture: Lecture
    let folderName: String?
    var showsFolderButton = true
    let onFolderTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LectureDetailTitleText(lecture: lecture)
                .font(.title)
                .bold()
                .lineLimit(3)

            if showsFolderButton {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        LectureDetailFolderButton(folderName: folderName, action: onFolderTap)
                        LectureDetailMetadataText(lecture: lecture)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        LectureDetailMetadataText(lecture: lecture)
                        LectureDetailFolderButton(folderName: folderName, action: onFolderTap)
                    }
                }
            } else {
                LectureDetailMetadataText(lecture: lecture)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LectureDetailFolderButton: View {
    let folderName: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                if let folderName {
                    Text(folderName)
                } else {
                    Text("Add to Folder")
                }
            } icon: {
                Image(systemName: folderName == nil ? "folder.badge.plus" : "folder")
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
