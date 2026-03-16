import SwiftUI
import RevenueCat
import RevenueCatUI

struct PaywallSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    var body: some View {
        NavigationStack {
            PaywallView()
                .onPurchaseCompleted { customerInfo in
                    subscriptionManager.update(from: customerInfo)
                    dismiss()
                }
                .onRestoreCompleted { customerInfo in
                    subscriptionManager.update(from: customerInfo)
                    dismiss()
                }
        }
    }
}

#Preview {
    PaywallSheetView()
        .environmentObject(SubscriptionManager())
}
