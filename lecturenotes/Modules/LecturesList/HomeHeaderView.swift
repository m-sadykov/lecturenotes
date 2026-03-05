import SwiftUI

struct HomeHeaderView: View {
    var body: some View {
        HStack {
            Text("LectureNotes")
                .font(.title)
                .bold()
            Spacer()
            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.05))
                    .clipShape(.circle)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
        }
    }
}
