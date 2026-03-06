import SwiftUI

struct FolderFilterChipsView: View {
    let folders: [LectureFolder]
    @Binding var selectedFolderID: LectureFolder.ID?

    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                FolderFilterChip(
                    title: "All",
                    isSelected: selectedFolderID == nil
                ) {
                    selectedFolderID = nil
                }

                ForEach(folders) { folder in
                    FolderFilterChip(
                        title: folder.name,
                        isSelected: selectedFolderID == folder.id
                    ) {
                        selectedFolderID = folder.id
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

private struct FolderFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? .black : .white)
                .clipShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
