import SwiftUI

struct PremiumBannerView: View {
    var body: some View {
        NavigationLink {
            PaywallView()
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text("Unlock Premium")
                        .font(.title3)
                        .bold()
                    Text("Up to 100 minutes per recording")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }
                
                Spacer()
                
                Image(systemName: "crown.fill")
                    .font(.title)
                    .padding()
                    .background(.white.opacity(0.18))
                    .clipShape(.rect(cornerRadius: 16))
            }
            .padding()
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.cyan],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
