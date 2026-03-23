import SwiftUI
import RevenueCatUI

@MainActor
struct LectureNotesRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var appState: AppState
    @State private var appEnvironment: AppEnvironment
    @State private var lecturesListViewModel: LecturesListViewModel
    @State private var paywallPresentationModel = PaywallPresentationModel()

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
            userProfileService: resolvedAppEnvironment.userProfileService
        )

        _appState = State(initialValue: resolvedAppState)
        _appEnvironment = State(initialValue: resolvedAppEnvironment)
        _lecturesListViewModel = State(initialValue: resolvedLecturesListViewModel)
    }

    var body: some View {
        let shouldMonitorScheduledDiscountPaywall = scenePhase == .active && !appState.needsOnboarding

        Group {
            if appState.needsOnboarding {
                OnboardingView(appState: appState)
            } else {
                LecturesListView(
                    viewModel: lecturesListViewModel,
                    paywallPresentationModel: paywallPresentationModel,
                    repository: appEnvironment.repository,
                    authService: appEnvironment.authService,
                    processingService: appEnvironment.processingService,
                    userProfileService: appEnvironment.userProfileService
                )
            }
        }
        .presentPaywall(
            offering: Binding(
                get: { paywallPresentationModel.presentedOffering },
                set: { paywallPresentationModel.presentedOffering = $0 }
            ),
            presentationMode: .fullScreen,
            purchaseCompleted: { customerInfo in
                subscriptionManager.update(from: customerInfo)
                paywallPresentationModel.handleSuccessfulPurchaseOrRestore()
            },
            restoreCompleted: { customerInfo in
                subscriptionManager.update(from: customerInfo)
                paywallPresentationModel.handleSuccessfulPurchaseOrRestore()
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
        .onChange(of: appState.needsOnboarding, initial: false) { oldValue, newValue in
            guard oldValue, !newValue else { return }

            Task {
                await paywallPresentationModel.presentDefaultPaywallAfterOnboardingIfNeeded(
                    for: subscriptionManager
                )
            }
        }
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            guard newPhase == .active else { return }
            guard !appState.needsOnboarding else { return }

            Task {
                await paywallPresentationModel.presentScheduledProYearlyDiscountPaywallIfNeeded(
                    for: subscriptionManager
                )
            }
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
    }
}
 
#Preview {
    LectureNotesRootView(
        appState: .preview(needsOnboarding: false),
        appEnvironment: .preview()
    )
    .environmentObject(SubscriptionManager())
}
