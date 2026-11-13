import SwiftUI

/// System "More" menu in the lecture detail toolbar, with folder, rename and delete actions.
struct LectureDetailActionsMenu: View {
    let onAddToFolder: () -> Void
    let onRemoveFromFolder: (() -> Void)?
    let onEditTitle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Menu {
            if let onRemoveFromFolder {
                LectureDetailActionsMenuItem(
                    title: "Remove from folder",
                    systemImage: "folder.badge.minus",
                    action: onRemoveFromFolder
                )
            } else {
                LectureDetailActionsMenuItem(
                    title: "Add to folder",
                    systemImage: "folder",
                    action: onAddToFolder
                )
            }

            LectureDetailActionsMenuItem(
                title: "Edit Title",
                systemImage: "pencil",
                action: onEditTitle
            )

            Divider()

            LectureDetailActionsMenuItem(
                title: "Delete",
                systemImage: "trash",
                role: .destructive,
                action: onDelete
            )
        } label: {
            Label {
                Text("Actions")
            } icon: {
                Image(systemName: "ellipsis")
            }
        }
    }
}

private struct LectureDetailActionsMenuItem: View {
    let title: LocalizedStringResource
    let systemImage: String
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
            }
        }
    }
}
