import SwiftUI

struct FolderSelectionSheet: View {
    let lecture: Lecture
    let folders: [LectureFolder]
    let selectedFolderID: LectureFolder.ID?
    let onCreateFolder: (String) -> Void
    let onSelectFolder: (LectureFolder.ID) -> Void
    let onClose: () -> Void

    var body: some View {
        FolderListContentView(
            title: "Select Folder",
            folders: folders,
            selectedFolderID: selectedFolderID,
            closeButton: CloseButton(title: "Close", systemImage: "xmark", action: onClose),
            onCreateFolder: onCreateFolder,
            onSelectFolder: onSelectFolder,
            onDeleteFolder: nil
        )
        .presentationDragIndicator(.visible)
    }
}
