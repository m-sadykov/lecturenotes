import SwiftUI

struct RecordingActionsSheet: View {
    let lecture: Lecture
    let onAddToFolder: () -> Void
    let onRemoveFromFolder: (() -> Void)?
    let onEditTitle: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

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

                if let onRemoveFromFolder {
                    ActionRowButton(
                        title: "Remove from folder",
                        systemImage: "folder.badge.minus",
                        role: .destructive,
                        action: onRemoveFromFolder
                    )
                } else {
                    ActionRowButton(title: "Add to folder", systemImage: "folder", action: onAddToFolder)
                }
                ActionRowButton(title: "Edit title", systemImage: "pencil", action: onEditTitle)
                ActionRowButton(title: "Share As", systemImage: "square.and.arrow.up", action: onShare)

                Divider()
                    .padding(.vertical, 8)

                Button("Delete", systemImage: "trash", role: .destructive) {
                    onDelete()
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .presentationDragIndicator(.visible)
    }
}

private struct ActionRowButton: View {
    let title: String
    let systemImage: String
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            HStack {
                Image(systemName: systemImage)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(role == .destructive ? .red : .secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? .red : .primary)
    }
}
