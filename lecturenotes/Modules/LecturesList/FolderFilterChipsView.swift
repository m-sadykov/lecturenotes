import SwiftUI

struct FolderFilterChipsView: View {
    let folders: [LectureFolder]
    @Binding var selectedFolderID: LectureFolder.ID?

    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                FolderFilterChip(
                    title: .localized("All"),
                    isSelected: selectedFolderID == nil
                ) {
                    selectedFolderID = nil
                }

                ForEach(folders) { folder in
                    FolderFilterChip(
                        title: .custom(folder.name),
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
    let title: ChipTitle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            chipLabel
                .font(.caption)
                .foregroundStyle(isSelected ? AppColor.onInk : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? AppColor.ink : AppColor.surface)
                .clipShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var chipLabel: some View {
        switch title {
        case .localized(let value):
            Text(value)
        case .custom(let value):
            Text(value)
        }
    }
}

private enum ChipTitle {
    case localized(LocalizedStringResource)
    case custom(String)
}
