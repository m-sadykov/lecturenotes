import SwiftUI

struct ImportLimitSheetView: View {
    let title: String
    let message: String
    let upgradeTitle: String
    let upgradeMessage: String
    let onViewPlans: () -> Void

    static let preferredSheetHeight: CGFloat = 470

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ImportLimitSheetIcon()
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

            VStack(alignment: .center, spacing: 12) {
                Text(title)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            ImportLimitUpgradeCard(
                title: upgradeTitle,
                message: upgradeMessage
            )

            Button("View Plans", action: onViewPlans)
                .buttonStyle(.importLimitPrimary)
        }
        .padding(24)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(.systemBackground))
    }
}

private struct ImportLimitSheetIcon: View {
    var body: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 42, weight: .semibold))
            .foregroundStyle(Color(red: 0.83, green: 0.25, blue: 0.28))
            .frame(width: 84, height: 84)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.99, green: 0.90, blue: 0.91),
                        Color(red: 1.0, green: 0.95, blue: 0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: .circle
            )
    }
}

private struct ImportLimitUpgradeCard: View {
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "crown.fill")
                .font(.subheadline)
                .foregroundStyle(Color(red: 0.29, green: 0.40, blue: 0.92))
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.78), in: .rect(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.97, blue: 1),
                    Color(red: 0.98, green: 0.99, blue: 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color(red: 0.82, green: 0.87, blue: 1), lineWidth: 1)
        }
    }
}

private struct ImportLimitPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.black)
            .clipShape(.rect(cornerRadius: 18))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private extension ButtonStyle where Self == ImportLimitPrimaryButtonStyle {
    static var importLimitPrimary: ImportLimitPrimaryButtonStyle {
        ImportLimitPrimaryButtonStyle()
    }
}

#Preview("Import Limit Sheet") {
    ImportLimitSheetPreview()
}

private struct ImportLimitSheetPreview: View {
    @State private var isPresented = true

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $isPresented) {
            ImportLimitSheetView(
                title: "Recording Too Long",
                message: "This recording is 37 minutes long, but your current plan allows only 5 minutes. Upgrade to import longer recordings.",
                upgradeTitle: "Upgrade to Pro",
                upgradeMessage: "Record up to 4 hours per recording with Pro.",
                onViewPlans: {}
            )
            .presentationDetents([.height(ImportLimitSheetView.preferredSheetHeight)])
            .presentationDragIndicator(.visible)
        }
    }
}
