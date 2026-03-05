import SwiftUI

struct RecordingsSectionHeaderView: View {
    var body: some View {
        HStack {
            Text("Recordings")
                .font(.title)
                .bold()
            Spacer()
            Image(systemName: "folder")
                .foregroundStyle(.blue)
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.blue)
        }
    }
}
