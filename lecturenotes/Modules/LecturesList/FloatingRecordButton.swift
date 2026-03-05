import SwiftUI

struct FloatingRecordButton: View {
    var body: some View {
        NavigationLink {
            RecorderView(viewModel: RecorderViewModel())
        } label: {
            Image(systemName: "mic.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(
                    LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(.circle)
                .shadow(radius: 8)
        }
        .buttonStyle(.plain)
    }
}
