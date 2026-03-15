import SwiftUI

@MainActor
struct LectureNotesRootView: View {
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
                LecturesListView(viewModel: LecturesListViewModel(repository: appEnvironment.repository))
            }
        }
    }
}
 
#Preview {
    LectureNotesRootView(
        appState: .preview(needsOnboarding: false),
        appEnvironment: .preview()
    )
}
