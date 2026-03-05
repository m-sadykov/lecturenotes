import SwiftUI

struct RecordingActionsSheet: View {
    let lecture: Lecture
    let onAddToFolder: () -> Void
    let onEditTitle: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading) {
                Text(lecture.title)
                    .font(.title2)
                    .bold()
                Text(lecture.createdAt, format: LectureFormatters.dayMonthYear)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()
                .padding(.bottom, 8)

            ActionRowButton(title: "Add to folder", systemImage: "folder", action: onAddToFolder)
            ActionRowButton(title: "Edit title", systemImage: "pencil", action: onEditTitle)
            ActionRowButton(title: "Share As", systemImage: "square.and.arrow.up", action: onShare)

            Divider()
                .padding(.vertical, 8)

            Button("Delete", systemImage: "trash", role: .destructive) {
                onDelete()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            Spacer(minLength: 0)
        }
        .presentationDragIndicator(.visible)
    }
}

private struct ActionRowButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}
