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
    static let proYearlyDiscountOfferingIdentifier = "pro_yearly_discount_offer"

    var presentedOffering: Offering?
    var isLoadingPaywall = false
    var paywallErrorMessage: String?

    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private let analyticsService: AppAnalyticsService?
    @ObservationIgnored private let crashReportingService: CrashReportingService?
    @ObservationIgnored private var activePresentationSource: PresentationSource?
    @ObservationIgnored private var didUnlockInActivePresentation = false
    @ObservationIgnored private var activeOfferingIdentifier: String?
    @ObservationIgnored private var activeProductIdentifier: String?

    private static let scheduledOfferPresentationInterval: TimeInterval = 3 * 60 * 60
    static let scheduledOfferPollingInterval: Duration = .seconds(60)
    private static let scheduledOfferLastPresentedAtKey = "paywall.proYearlyDiscountOffer.lastPresentedAt"

    init(
        userDefaults: UserDefaults = .standard,
        analyticsService: AppAnalyticsService? = nil,
        crashReportingService: CrashReportingService? = nil
    ) {
        self.userDefaults = userDefaults
        self.analyticsService = analyticsService
        self.crashReportingService = crashReportingService
    }

    func presentDefaultPaywall() async {
        _ = await presentPaywall(
            offeringIdentifier: Self.defaultOfferingIdentifier,
            fallbackToCurrentOffering: true,
            showsError: true,
            source: .manualDefault
        )
    }

    func presentDefaultPaywallIfNeeded(
        for subscriptionManager: SubscriptionManager
    ) async {
        guard shouldAllowPaywallPresentation(for: subscriptionManager.currentPlan) else { return }
        guard presentedOffering == nil else { return }

        await presentDefaultPaywall()
    }

    func presentDefaultPaywallAfterOnboardingIfNeeded(
        for subscriptionManager: SubscriptionManager
    ) async {
        guard shouldAllowPaywallPresentation(for: subscriptionManager.currentPlan) else { return }
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
        guard shouldAllowPaywallPresentation(for: subscriptionManager.currentPlan) else { return }
        guard presentedOffering == nil else { return }
        guard shouldPresentScheduledOffer else { return }

        let didPresent = await presentPaywall(
            offeringIdentifier: Self.proYearlyDiscountOfferingIdentifier,
            fallbackToCurrentOffering: false,
            showsError: false,
            source: .scheduledDiscount
        )

        if didPresent {
            markScheduledOfferAnchorNow()
        }
    }

    func markScheduledOfferAnchorFromAppBackgroundIfNeeded(
        for subscriptionManager: SubscriptionManager,
        isOnboardingRequired: Bool
    ) {
        guard !isOnboardingRequired else { return }
        guard shouldAllowPaywallPresentation(for: subscriptionManager.currentPlan) else { return }
        guard presentedOffering == nil else { return }

        markScheduledOfferAnchorNow()
    }

    func handleSuccessfulPurchaseOrRestore() {
        didUnlockInActivePresentation = true
    }

    func handlePurchaseStarted(_ package: Package, currentPlan: AppUserPlan) {
        activeOfferingIdentifier = package.offeringIdentifier
        activeProductIdentifier = package.storeProduct.productIdentifier
        crashReportingService?.setCurrentFlow("purchase")
        crashReportingService?.breadcrumb(
            "purchase_flow_started",
            metadata: [
                "product_id": package.storeProduct.productIdentifier,
                "offering_id": package.offeringIdentifier,
            ]
        )
        analyticsService?.track(
            .purchaseStarted(
                productID: package.storeProduct.productIdentifier,
                offeringID: package.offeringIdentifier,
                planFrom: currentPlan
            )
        )
    }

    func handlePurchaseSuccess(_ customerInfo: CustomerInfo, currentPlan: AppUserPlan) {
        analyticsService?.track(
            .purchaseSuccess(
                productID: activeProductIdentifier,
                offeringID: activeOfferingIdentifier,
                planFrom: currentPlan,
                planTo: resolvePlan(from: customerInfo)
            )
        )
    }

    func handlePurchaseCancelled(currentPlan: AppUserPlan) {
        crashReportingService?.breadcrumb(
            "purchase_cancelled",
            metadata: [
                "product_id": activeProductIdentifier ?? "",
                "offering_id": activeOfferingIdentifier ?? "",
            ]
        )
        analyticsService?.track(
            .purchaseCancelled(
                productID: activeProductIdentifier,
                offeringID: activeOfferingIdentifier,
                planFrom: currentPlan
            )
        )
    }

    func handlePurchaseFailure(_ error: Error, currentPlan: AppUserPlan) {
        crashReportingService?.recordNonFatal(
            error,
            reason: "purchase_failed",
            metadata: [
                "product_id": activeProductIdentifier ?? "",
                "offering_id": activeOfferingIdentifier ?? "",
            ]
        )
        analyticsService?.track(
            .purchaseFailed(
                productID: activeProductIdentifier,
                offeringID: activeOfferingIdentifier,
                planFrom: currentPlan,
                error: error
            )
        )
    }

    func handleRestoreStarted(currentPlan: AppUserPlan) {
        crashReportingService?.breadcrumb("restore_purchases_started")
        analyticsService?.track(.restorePurchasesStarted(plan: currentPlan))
    }

    func handleRestoreCompleted(_ customerInfo: CustomerInfo, currentPlan: AppUserPlan) {
        let restoredPlan = resolvePlan(from: customerInfo)
        let result = restoredPlan == currentPlan && restoredPlan == .freemium ? "no_active_purchases" : "success"
        crashReportingService?.breadcrumb(
            "restore_purchases_completed",
            metadata: [
                "result": result,
                "restored_plan": restoredPlan.rawValue,
            ]
        )
        analyticsService?.track(
            .restorePurchasesResult(
                result: result,
                restoredPlan: restoredPlan
            )
        )
    }

    func handlePaywallDismissal(for subscriptionManager: SubscriptionManager) {
        defer {
            activePresentationSource = nil
            didUnlockInActivePresentation = false
            activeOfferingIdentifier = nil
            activeProductIdentifier = nil
        }

        guard shouldAllowPaywallPresentation(for: subscriptionManager.currentPlan), !didUnlockInActivePresentation else {
            return
        }

        switch activePresentationSource {
        case .postOnboarding, .scheduledDiscount:
            markScheduledOfferAnchorNow()
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
        crashReportingService?.setCurrentFlow("paywall")
        crashReportingService?.breadcrumb(
            "paywall_load_started",
            metadata: [
                "source": analyticsValue(for: source),
                "offering_id": offeringIdentifier,
            ]
        )

        do {
            let offerings = try await Purchases.shared.offerings()
            let resolvedOffering = offerings.offering(identifier: offeringIdentifier)
            let fallbackOffering = fallbackToCurrentOffering ? offerings.current : nil

            guard let offering = resolvedOffering ?? fallbackOffering else {
                if showsError {
                    paywallErrorMessage = String(localized: "Paywall is unavailable right now.")
                }
                return false
            }

            activePresentationSource = source
            didUnlockInActivePresentation = false
            presentedOffering = offering
            analyticsService?.track(
                .paywallShown(
                    source: analyticsValue(for: source),
                    offeringID: offering.identifier,
                    currentPlan: nil
                )
            )
            return true
        } catch {
            if showsError {
                paywallErrorMessage = String(localized: "Paywall is unavailable right now.")
            }
            crashReportingService?.recordNonFatal(
                error,
                reason: "paywall_load_failed",
                metadata: [
                    "source": analyticsValue(for: source),
                    "offering_id": offeringIdentifier,
                ]
            )
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

    private func shouldAllowPaywallPresentation(for currentPlan: AppUserPlan) -> Bool {
        currentPlan == .freemium
    }

    private func markScheduledOfferAnchorNow() {
        userDefaults.set(Date.now, forKey: Self.scheduledOfferLastPresentedAtKey)
    }

    private func resolvePlan(from customerInfo: CustomerInfo) -> AppUserPlan {
        if customerInfo.entitlements[SubscriptionManager.proEntitlementIdentifier]?.isActive == true {
            return .pro
        }

        if customerInfo.entitlements[SubscriptionManager.premiumEntitlementIdentifier]?.isActive == true {
            return .premium
        }

        return .freemium
    }

    private func analyticsValue(for source: PresentationSource) -> String {
        switch source {
        case .postOnboarding:
            "post_onboarding"
        case .manualDefault:
            "manual_default"
        case .scheduledDiscount:
            "scheduled_discount"
        }
    }
}

#Preview {
    Color.clear
}
