import SwiftUI
import RevenueCatUI

@MainActor
struct LectureNotesRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var appState: AppState
    @State private var appEnvironment: AppEnvironment
    @State private var lecturesListViewModel: LecturesListViewModel
    @State private var paywallPresentationModel: PaywallPresentationModel

    init(
        appState: AppState? = nil,
        appEnvironment: AppEnvironment? = nil,
        lecturesListViewModel: LecturesListViewModel? = nil
    ) {
        let resolvedAppState = appState ?? AppState()
        let resolvedAppEnvironment = appEnvironment ?? AppEnvironment()
        let resolvedLecturesListViewModel = lecturesListViewModel ?? LecturesListViewModel(
            repository: resolvedAppEnvironment.repository,
            processingService: resolvedAppEnvironment.processingService,
            userProfileService: resolvedAppEnvironment.userProfileService,
            analyticsService: resolvedAppEnvironment.analyticsService
        )

        _appState = State(initialValue: resolvedAppState)
        _appEnvironment = State(initialValue: resolvedAppEnvironment)
        _lecturesListViewModel = State(initialValue: resolvedLecturesListViewModel)
        _paywallPresentationModel = State(
            initialValue: PaywallPresentationModel(analyticsService: resolvedAppEnvironment.analyticsService)
        )
    }

    var body: some View {
        let shouldMonitorScheduledDiscountPaywall = scenePhase == .active && !appState.needsOnboarding
        let currentUserProfile = appEnvironment.userProfileService?.currentProfile

        Group {
            if appState.needsOnboarding {
                OnboardingView(
                    appState: appState,
                    analyticsService: appEnvironment.analyticsService
                )
            } else {
                LecturesListView(
                    viewModel: lecturesListViewModel,
                    paywallPresentationModel: paywallPresentationModel,
                    repository: appEnvironment.repository,
                    authService: appEnvironment.authService,
                    processingService: appEnvironment.processingService,
                    userProfileService: appEnvironment.userProfileService,
                    analyticsService: appEnvironment.analyticsService
                )
            }
        }
        .presentPaywall(
            offering: Binding(
                get: { paywallPresentationModel.presentedOffering },
                set: { paywallPresentationModel.presentedOffering = $0 }
            ),
            presentationMode: .fullScreen,
            purchaseStarted: { package in
                paywallPresentationModel.handlePurchaseStarted(
                    package,
                    currentPlan: subscriptionManager.currentPlan
                )
            },
            purchaseCompleted: { customerInfo in
                paywallPresentationModel.handlePurchaseSuccess(
                    customerInfo,
                    currentPlan: subscriptionManager.currentPlan
                )
                subscriptionManager.update(from: customerInfo)
                paywallPresentationModel.handleSuccessfulPurchaseOrRestore()
            },
            purchaseCancelled: {
                paywallPresentationModel.handlePurchaseCancelled(currentPlan: subscriptionManager.currentPlan)
            },
            restoreStarted: {
                paywallPresentationModel.handleRestoreStarted(currentPlan: subscriptionManager.currentPlan)
            },
            restoreCompleted: { customerInfo in
                paywallPresentationModel.handleRestoreCompleted(
                    customerInfo,
                    currentPlan: subscriptionManager.currentPlan
                )
                subscriptionManager.update(from: customerInfo)
                paywallPresentationModel.handleSuccessfulPurchaseOrRestore()
            },
            purchaseFailure: { error in
                paywallPresentationModel.handlePurchaseFailure(
                    error,
                    currentPlan: subscriptionManager.currentPlan
                )
            },
            onDismiss: {
                paywallPresentationModel.handlePaywallDismissal(for: subscriptionManager)
            }
        )
        .alert(
            "Paywall unavailable",
            isPresented: Binding(
                get: { paywallPresentationModel.paywallErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        paywallPresentationModel.dismissPaywallError()
                    }
                }
            )
        ) {
            Button("OK") {
                paywallPresentationModel.dismissPaywallError()
            }
        } message: {
            Text(paywallPresentationModel.paywallErrorMessage ?? "")
        }
        .onChange(of: currentUserProfile, initial: true) { oldValue, newValue in
            guard didExhaustFreemiumProcessingQuota(from: oldValue, to: newValue) else { return }

            Task {
                await paywallPresentationModel.presentDefaultPaywallIfNeeded(for: subscriptionManager)
            }
        }
        .onChange(of: lecturesListViewModel.processingLimitReachedToken, initial: false) { oldValue, newValue in
            guard newValue > oldValue else { return }

            Task {
                await paywallPresentationModel.presentDefaultPaywallIfNeeded(for: subscriptionManager)
            }
        }
        .onChange(of: appState.needsOnboarding, initial: false) { oldValue, newValue in
            guard oldValue, !newValue else { return }

            Task {
                await paywallPresentationModel.presentDefaultPaywallAfterOnboardingIfNeeded(
                    for: subscriptionManager
                )
            }
        }
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            switch newPhase {
            case .active:
                guard !appState.needsOnboarding else { return }

                Task {
                    await paywallPresentationModel.presentScheduledProYearlyDiscountPaywallIfNeeded(
                        for: subscriptionManager
                    )
                }
            case .background:
                paywallPresentationModel.markScheduledOfferAnchorFromAppBackgroundIfNeeded(
                    for: subscriptionManager,
                    isOnboardingRequired: appState.needsOnboarding
                )
            default:
                return
            }
        }
        .onChange(of: subscriptionManager.currentPlan, initial: true) { _, newPlan in
            appEnvironment.analyticsService.setUserProperties(
                plan: newPlan,
                language: appState.selectedLanguage,
                isPremium: newPlan != .freemium
            )
        }
        .onChange(of: appState.selectedLanguage, initial: true) { _, newLanguage in
            appEnvironment.analyticsService.setUserProperties(
                plan: subscriptionManager.currentPlan,
                language: newLanguage,
                isPremium: subscriptionManager.currentPlan != .freemium
            )
        }
        .task(id: shouldMonitorScheduledDiscountPaywall) {
            guard shouldMonitorScheduledDiscountPaywall else { return }

            while !Task.isCancelled {
                if paywallPresentationModel.hasScheduledOfferAnchor {
                    await paywallPresentationModel.presentScheduledProYearlyDiscountPaywallIfNeeded(
                        for: subscriptionManager
                    )
                }

                do {
                    try await Task.sleep(for: PaywallPresentationModel.scheduledOfferPollingInterval)
                } catch {
                    return
                }
            }
        }
        .task {
            subscriptionManager.start()
            await appEnvironment.repository.start()
            await appEnvironment.userProfileService?.prepareCurrentUserProfile()
            await lecturesListViewModel.load()
        }
        .environment(appState)
    }

    private func didExhaustFreemiumProcessingQuota(
        from oldProfile: AppUserProfile?,
        to newProfile: AppUserProfile?
    ) -> Bool {
        guard let newProfile else {
            return false
        }

        guard newProfile.plan == .freemium, !newProfile.processingQuota.isUnlimited else {
            return false
        }

        guard newProfile.processingQuota.remainingCount == 0 else {
            return false
        }

        guard let oldProfile else {
            return false
        }

        return oldProfile.processingQuota.isUnlimited || oldProfile.processingQuota.remainingCount > 0
    }
}
 
#Preview {
    LectureNotesRootView(
        appState: .preview(needsOnboarding: false),
        appEnvironment: .preview()
    )
    .environmentObject(SubscriptionManager())
}
