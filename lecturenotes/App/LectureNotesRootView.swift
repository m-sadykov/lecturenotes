import SwiftUI

@MainActor
struct LectureNotesRootView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var appState: AppState
    @State private var appEnvironment: AppEnvironment
    @State private var lecturesListViewModel: LecturesListViewModel

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
        Group {
            if appState.needsOnboarding {
                OnboardingView(appState: appState)
            } else {
                LecturesListView(
                    viewModel: lecturesListViewModel,
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
