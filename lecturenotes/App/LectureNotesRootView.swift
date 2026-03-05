import SwiftUI

struct LectureNotesRootView: View {
    @State private var appState = AppState()
    @State private var appEnvironment = AppEnvironment()

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
    LectureNotesRootView()
}
