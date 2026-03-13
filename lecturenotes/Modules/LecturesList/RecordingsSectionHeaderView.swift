import SwiftUI

struct RecordingsSectionHeaderView: View {
    let foldersDestination: FoldersScreen
    let showsFoldersNavigation: Bool

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
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "folder")
                    .foregroundStyle(.blue.opacity(0.5))
            }

            Button("Search", systemImage: "magnifyingglass") {}
                .labelStyle(.iconOnly)
                .foregroundStyle(.blue)
                .buttonStyle(.plain)
        }
    }
}
