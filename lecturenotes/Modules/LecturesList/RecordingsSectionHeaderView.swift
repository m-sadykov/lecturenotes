import SwiftUI

struct RecordingsSectionHeaderView: View {
    let foldersDestination: FoldersScreen
    let showsFoldersNavigation: Bool
    let onSearchTap: () -> Void

    var body: some View {
        HStack {
            Text("Recordings")
                .font(.title)
                .bold()
            Spacer()
            if showsFoldersNavigation {
                NavigationLink {
                    foldersDestination
                } label: {
                    Image(systemName: "folder")
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "folder")
                    .foregroundStyle(.primary.opacity(0.5))
            }

            Button("Search", systemImage: "magnifyingglass", action: onSearchTap)
                .labelStyle(.iconOnly)
                .foregroundStyle(.primary)
                .buttonStyle(.plain)
        }
    }
}
