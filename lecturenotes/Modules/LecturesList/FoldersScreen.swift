import Observation
import SwiftUI

struct FoldersScreen: View {
    @Bindable var viewModel: LecturesListViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        FolderListContentView(
            title: "Folders",
            folders: viewModel.folders,
            selectedFolderID: viewModel.selectedFolderID,
            closeButton: nil,
            backgroundStyle: AppColor.canvas,
            onCreateFolder: { folderName in
                viewModel.createFolder(named: folderName)
            },
            onSelectFolder: { folderID in
                viewModel.selectedFolderID = folderID
                dismiss()
            },
            onDeleteFolder: { folderID in
                viewModel.deleteFolder(folderID)
            }
        )
        .navigationTitle("Folders")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        FoldersScreen(viewModel: LecturesListViewModel(repository: MockLectureRepository()))
    }
}
