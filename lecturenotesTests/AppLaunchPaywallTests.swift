import Foundation
import Testing
@testable import lecturenotes

/// Covers the paths of the cold-start paywall that never reach RevenueCat.
@MainActor
struct AppLaunchPaywallTests {
    private func makeModel(scheduledOfferAnchor: Date? = nil) -> PaywallPresentationModel {
        let suiteName = "AppLaunchPaywallTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        if let scheduledOfferAnchor {
            userDefaults.set(scheduledOfferAnchor, forKey: "paywall.proYearlyDiscountOffer.lastPresentedAt")
        }
        return PaywallPresentationModel(userDefaults: userDefaults)
    }

    /// An anchor old enough that the scheduled discount is due.
    private static let dueScheduledOfferAnchor = Date.now.addingTimeInterval(-4 * 60 * 60)

    @Test(arguments: [AppUserPlan.premium, .pro])
    func paidPlansDoNotSeeLaunchPaywall(plan: AppUserPlan) async {
        let model = makeModel()

        await model.presentAppLaunchPaywallIfNeeded(for: plan, isOnboardingRequired: false)

        #expect(model.hasHandledAppLaunchPaywall)
        #expect(model.presentedOffering == nil)
        #expect(model.isLoadingPaywall == false)
    }

    @Test func launchIntoOnboardingSkipsLaunchPaywall() async {
        let model = makeModel()

        await model.presentAppLaunchPaywallIfNeeded(for: .freemium, isOnboardingRequired: true)

        #expect(model.hasHandledAppLaunchPaywall)
        #expect(model.presentedOffering == nil)
        #expect(model.isLoadingPaywall == false)
    }

    @Test func launchPaywallIsConsideredOncePerProcess() async {
        let model = makeModel()
        await model.presentAppLaunchPaywallIfNeeded(for: .premium, isOnboardingRequired: false)

        // A later freemium update in the same process (for example after a lapsed plan) must not reopen it.
        await model.presentAppLaunchPaywallIfNeeded(for: .freemium, isOnboardingRequired: false)

        #expect(model.presentedOffering == nil)
        #expect(model.isLoadingPaywall == false)
    }

    @Test func scheduledDiscountWaitsForLaunchPaywall() {
        let model = makeModel(scheduledOfferAnchor: Self.dueScheduledOfferAnchor)

        // Before RevenueCat answers, the plan is only the freemium placeholder.
        #expect(model.canPresentScheduledOffer(for: .freemium) == false)
    }

    @Test func scheduledDiscountIsAllowedAfterLaunchPaywallIsHandled() async {
        let model = makeModel(scheduledOfferAnchor: Self.dueScheduledOfferAnchor)

        // Onboarding marks the launch paywall handled without reaching RevenueCat.
        await model.presentAppLaunchPaywallIfNeeded(for: .freemium, isOnboardingRequired: true)

        #expect(model.canPresentScheduledOffer(for: .freemium))
        #expect(model.canPresentScheduledOffer(for: .pro) == false)
    }

    @Test func scheduledDiscountWaitsForItsInterval() async {
        let model = makeModel(scheduledOfferAnchor: .now)
        await model.presentAppLaunchPaywallIfNeeded(for: .freemium, isOnboardingRequired: true)

        #expect(model.canPresentScheduledOffer(for: .freemium) == false)
    }
}
