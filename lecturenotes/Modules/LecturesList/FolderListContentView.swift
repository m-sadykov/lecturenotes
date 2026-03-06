import SwiftUI

struct FolderListContentView: View {
    let title: String
    let folders: [LectureFolder]
    let selectedFolderID: LectureFolder.ID?
    let closeButton: CloseButton?
    let onCreateFolder: (String) -> Void
    let onSelectFolder: (LectureFolder.ID) -> Void
    let onDeleteFolder: ((LectureFolder.ID) -> Void)?

    @State private var isCreateFolderAlertPresented = false
    @State private var newFolderName = ""
    @State private var folderPendingDeletion: LectureFolder?

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(title)
                        .font(.title3)
                        .bold()

                    Spacer()

                    if let closeButton {
                        Button(closeButton.title, systemImage: closeButton.systemImage, action: closeButton.action)
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                Divider()

                Button {
                    newFolderName = ""
                    isCreateFolderAlertPresented = true
                } label: {
                    HStack {
                        Image(systemName: "plus")
                            .foregroundStyle(.green)
                            .frame(width: 44, height: 44)
                            .background(.green.opacity(0.12))
                            .clipShape(.rect(cornerRadius: 12))

                        Text("Create new folder")
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)

                Divider()
                    .padding(.horizontal, 20)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(folders) { folder in
                            FolderRowButton(
                                folder: folder,
                                isSelected: folder.id == selectedFolderID
                            ) {
                                onSelectFolder(folder.id)
                            } onDelete: {
                                folderPendingDeletion = folder
                            }

                            if folder.id != folders.last?.id {
                                Divider()
                                    .padding(.leading, 84)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .alert("Create Folder", isPresented: $isCreateFolderAlertPresented) {
            TextField("Folder name", text: $newFolderName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                let trimmedName = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedName.isEmpty else {
                    return
                }
                onCreateFolder(trimmedName)
            }
        } message: {
            Text("Add a new folder.")
        }
        .alert(
            "Delete Folder",
            isPresented: Binding(
                get: { folderPendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        folderPendingDeletion = nil
                    }
                }
            ),
            presenting: folderPendingDeletion
        ) { folder in
            Button("Cancel", role: .cancel) {
                folderPendingDeletion = nil
            }
            Button("Delete", role: .destructive) {
                onDeleteFolder?(folder.id)
                folderPendingDeletion = nil
            }
        } message: { folder in
            Text("Delete \"\(folder.name)\"? Recordings will remain available and will just be removed from this folder.")
        }
    }
}

struct CloseButton {
    let title: String
    let systemImage: String
    let action: () -> Void
}

struct FolderRowButton: View {
    let folder: LectureFolder
    let isSelected: Bool
    let action: () -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        HStack {
            Button(action: action) {
                HStack {
                    Image(systemName: "folder")
                        .foregroundStyle(.indigo)
                        .frame(width: 44, height: 44)
                        .background(.indigo.opacity(0.10))
                        .clipShape(.rect(cornerRadius: 12))

                    Text(folder.name)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)

            if let onDelete {
                Button("Delete folder", systemImage: "trash", role: .destructive, action: onDelete)
                    .labelStyle(.iconOnly)
                    .padding(.trailing, 20)
            }
        }
    }
}
