import SwiftUI

struct QuickActionButtonView: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .center) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .frame(width: 80, height: 70)
                    .background(.black.opacity(0.05))
                    .clipShape(.rect(cornerRadius: 14))
                Text(title)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .buttonStyle(.plain)
    }
}
