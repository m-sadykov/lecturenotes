import SwiftUI
import Observation
import RevenueCat
import RevenueCatUI

@MainActor
@Observable
final class PaywallPresentationModel {
    private enum PresentationSource {
        case postOnboarding
        case manualDefault
        case scheduledDiscount
    }

    static let defaultOfferingIdentifier = "default"
    static let proYearlyDiscountOfferingIdentifier = "com.marat.lecturenotesai_pro_annual_discount"

    var presentedOffering: Offering?
    var isLoadingPaywall = false
    var paywallErrorMessage: String?

    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private var activePresentationSource: PresentationSource?
    @ObservationIgnored private var didUnlockInActivePresentation = false

    private static let scheduledOfferPresentationInterval: TimeInterval = 4 * 60 * 60
    static let scheduledOfferPollingInterval: Duration = .seconds(60)
    private static let scheduledOfferLastPresentedAtKey = "paywall.proYearlyDiscountOffer.lastPresentedAt"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func presentDefaultPaywall() async {
        _ = await presentPaywall(
            offeringIdentifier: Self.defaultOfferingIdentifier,
            fallbackToCurrentOffering: true,
            showsError: true,
            source: .manualDefault
        )
    }

    func presentDefaultPaywallAfterOnboardingIfNeeded(
        for subscriptionManager: SubscriptionManager
    ) async {
        guard subscriptionManager.currentPlan == .freemium else { return }
        guard presentedOffering == nil else { return }

        _ = await presentPaywall(
            offeringIdentifier: Self.defaultOfferingIdentifier,
            fallbackToCurrentOffering: true,
            showsError: true,
            source: .postOnboarding
        )
    }

    func presentScheduledProYearlyDiscountPaywallIfNeeded(
        for subscriptionManager: SubscriptionManager
    ) async {
        guard subscriptionManager.currentPlan == .freemium else { return }
        guard presentedOffering == nil else { return }
        guard shouldPresentScheduledOffer else { return }

        let didPresent = await presentPaywall(
            offeringIdentifier: Self.proYearlyDiscountOfferingIdentifier,
            fallbackToCurrentOffering: false,
            showsError: false,
            source: .scheduledDiscount
        )

        if didPresent {
            userDefaults.set(Date.now, forKey: Self.scheduledOfferLastPresentedAtKey)
        }
    }

    func handleSuccessfulPurchaseOrRestore() {
        didUnlockInActivePresentation = true
    }

    func handlePaywallDismissal(for subscriptionManager: SubscriptionManager) {
        defer {
            activePresentationSource = nil
            didUnlockInActivePresentation = false
        }

        guard subscriptionManager.currentPlan == .freemium, !didUnlockInActivePresentation else {
            return
        }

        switch activePresentationSource {
        case .postOnboarding, .scheduledDiscount:
            userDefaults.set(Date.now, forKey: Self.scheduledOfferLastPresentedAtKey)
        case .manualDefault, .none:
            break
        }
    }

    @discardableResult
    private func presentPaywall(
        offeringIdentifier: String,
        fallbackToCurrentOffering: Bool,
        showsError: Bool,
        source: PresentationSource
    ) async -> Bool {
        guard !isLoadingPaywall else { return false }
        isLoadingPaywall = true
        defer { isLoadingPaywall = false }

        do {
            let offerings = try await Purchases.shared.offerings()
            let resolvedOffering = offerings.offering(identifier: offeringIdentifier)
            let fallbackOffering = fallbackToCurrentOffering ? offerings.current : nil

            guard let offering = resolvedOffering ?? fallbackOffering else {
                if showsError {
                    paywallErrorMessage = "Paywall is unavailable right now."
                }
                return false
            }

            activePresentationSource = source
            didUnlockInActivePresentation = false
            presentedOffering = offering
            return true
        } catch {
            if showsError {
                paywallErrorMessage = "Paywall is unavailable right now."
            }
            return false
        }
    }

    func dismissPaywallError() {
        paywallErrorMessage = nil
    }

    var hasScheduledOfferAnchor: Bool {
        scheduledOfferLastPresentedAt != nil
    }

    private var shouldPresentScheduledOffer: Bool {
        guard let lastPresentedAt = scheduledOfferLastPresentedAt else { return false }

        return Date.now.timeIntervalSince(lastPresentedAt) >= Self.scheduledOfferPresentationInterval
    }

    private var scheduledOfferLastPresentedAt: Date? {
        userDefaults.object(forKey: Self.scheduledOfferLastPresentedAtKey) as? Date
    }
}

#Preview {
    Color.clear
}
