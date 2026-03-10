import SwiftUI

struct FloatingRecordButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
