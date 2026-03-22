import SwiftUI

@MainActor
struct LectureNotesRootView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var appState: AppState
    @State private var appEnvironment: AppEnvironment

    init(
        appState: AppState? = nil,
        appEnvironment: AppEnvironment? = nil
    ) {
        _appState = State(initialValue: appState ?? AppState())
        _appEnvironment = State(initialValue: appEnvironment ?? AppEnvironment())
    }

    var body: some View {
        Group {
            if appState.needsOnboarding {
                OnboardingView(appState: appState)
            } else {
                LecturesListView(
                    viewModel: LecturesListViewModel(
                        repository: appEnvironment.repository,
                        processingService: appEnvironment.processingService,
                        userProfileService: appEnvironment.userProfileService
                    ),
                    repository: appEnvironment.repository,
                    authService: appEnvironment.authService,
                    processingService: appEnvironment.processingService,
                    userProfileService: appEnvironment.userProfileService
                )
            }
        }
        .task {
            subscriptionManager.start()
            await appEnvironment.repository.start()
            await appEnvironment.userProfileService?.prepareCurrentUserProfile()
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
