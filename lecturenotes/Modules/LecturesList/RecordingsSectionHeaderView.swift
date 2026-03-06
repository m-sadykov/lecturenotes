import SwiftUI

struct RecordingsSectionHeaderView: View {
    let foldersDestination: FoldersScreen

    var body: some View {
        HStack {
            Text("Recordings")
                .font(.title)
                .bold()
            Spacer()
            NavigationLink {
                foldersDestination
            } label: {
                Image(systemName: "folder")
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)

            Button("Search", systemImage: "magnifyingglass") {}
                .labelStyle(.iconOnly)
                .foregroundStyle(.blue)
                .buttonStyle(.plain)
        }
    }
}
