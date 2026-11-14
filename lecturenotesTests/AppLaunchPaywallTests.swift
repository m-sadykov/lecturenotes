import Foundation
import Testing
@testable import lecturenotes

/// Covers the paths of the cold-start paywall that never reach RevenueCat.
@MainActor
struct AppLaunchPaywallTests {
    private func makeModel() -> PaywallPresentationModel {
        let suiteName = "AppLaunchPaywallTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        return PaywallPresentationModel(userDefaults: userDefaults)
    }

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
}
