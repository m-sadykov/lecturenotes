import SwiftUI
import RevenueCat
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        return true
    }
}

@main
struct lecturenotesApp: App {
    private let firebaseConfigured: Void = {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }()

    @StateObject private var subscriptionManager: SubscriptionManager
    @State private var appEnvironment: AppEnvironment

    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        _ = firebaseConfigured

        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: "appl_gocyBRrDByBgmJWEJvORYtfBjUX")

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
            LectureNotesRootView(appEnvironment: appEnvironment)
                .preferredColorScheme(.light)
                .environmentObject(subscriptionManager)
        }
    }
}
