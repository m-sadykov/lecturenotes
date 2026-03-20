import SwiftUI
import RevenueCat

@main
struct lecturenotesApp: App {
    @StateObject private var subscriptionManager: SubscriptionManager
    @State private var appEnvironment: AppEnvironment
    
    init() {
        FirebaseBootstrapper.configureIfNeeded()

        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: "test_WiOttVRhcRMJqvByDuPjYzOGNOy")

        let authService = FirebaseAuthService()
        let userProfileService = FirebaseUserProfileService(authService: authService)
        _subscriptionManager = StateObject(
            wrappedValue: SubscriptionManager(userProfileService: userProfileService)
        )
        _appEnvironment = State(
            initialValue: AppEnvironment(
                authService: authService,
                userProfileService: userProfileService
            )
        )
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                LectureNotesRootView(appEnvironment: appEnvironment)
                    .preferredColorScheme(.light)
                    .environmentObject(subscriptionManager)
            }
        }
    }
}
