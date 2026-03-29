import SwiftUI

struct LectureDetailActionsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onAddToFolder: () -> Void
    let onRemoveFromFolder: (() -> Void)?
    let onEditTitle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let onRemoveFromFolder {
                LectureDetailActionRowButton(
                    title: "Remove from folder",
                    systemImage: "folder.badge.minus",
                    action: {
                        dismiss()
                        Task {
                            await Task.yield()
                            onRemoveFromFolder()
                        }
                    }
                )
            } else {
                LectureDetailActionRowButton(
                    title: "Add to folder",
                    systemImage: "folder",
                    action: {
                        dismiss()
                        Task {
                            await Task.yield()
                            onAddToFolder()
                        }
                    }
                )
            }

            LectureDetailActionRowButton(
                title: "Edit Title",
                systemImage: "pencil",
                action: {
                    dismiss()
                    Task {
                        await Task.yield()
                        onEditTitle()
                    }
                }
            )

            Divider()
                .padding(.vertical, 8)

            LectureDetailActionRowButton(
                title: "Delete",
                systemImage: "trash",
                role: .destructive,
                action: {
                    dismiss()
                    Task {
                        await Task.yield()
                        onDelete()
                    }
                }
            )
            .padding(.bottom, 8)
        }
        .frame(width: 280, alignment: .topLeading)
        .padding(.vertical, 4)
    }
}

private struct LectureDetailActionRowButton: View {
    let title: LocalizedStringResource
    let systemImage: String
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            HStack {
                Image(systemName: systemImage)
                Text(title)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? .red : .primary)
    }
}
