import SwiftUI
import FirebaseCore
import RevenueCat

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}

@main
struct lecturenotesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var subscriptionManager: SubscriptionManager
    @State private var appEnvironment: AppEnvironment
    
    init() {
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
