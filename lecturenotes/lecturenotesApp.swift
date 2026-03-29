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
    
    @State private var appState: AppState
    @State private var appEnvironment: AppEnvironment
    @State private var lecturesListViewModel: LecturesListViewModel
    @State private var isSplashVisible = true
    @State private var splashProgress = 0.0
    @State private var hasPreparedStartup = false

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
        let environment = AppEnvironment(
            authService: authService,
            userProfileService: userProfileService
        )
        _subscriptionManager = StateObject(
            wrappedValue: SubscriptionManager(userProfileService: userProfileService)
        )
        _appState = State(initialValue: AppState())
        _appEnvironment = State(
            initialValue: environment
        )
        _lecturesListViewModel = State(
            initialValue: LecturesListViewModel(
                repository: environment.repository,
                processingService: environment.processingService,
                userProfileService: environment.userProfileService
            )
        )
    }
    
    private func prepareStartupIfNeeded() async {
        guard !hasPreparedStartup else { return }
        hasPreparedStartup = true

        await updateSplashProgress(to: 0.15)
        subscriptionManager.start()

        await appEnvironment.repository.start()
        await updateSplashProgress(to: 0.4)

        await appEnvironment.userProfileService?.prepareCurrentUserProfile()
        await updateSplashProgress(to: 0.65)

        await subscriptionManager.refresh()
        await updateSplashProgress(to: 0.82)

        await lecturesListViewModel.load()
        await updateSplashProgress(to: 1.0)

        await MainActor.run {
            withAnimation(.easeOut(duration: 0.25)) {
                isSplashVisible = false
            }
        }
    }

    private func updateSplashProgress(to value: Double) async {
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.2)) {
                splashProgress = value
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isSplashVisible {
                    SplashScreenView(progress: splashProgress)
                        .transition(.opacity)
                        .zIndex(1)
                        .task() {
                            await prepareStartupIfNeeded()
                        }
                } else {
                    LectureNotesRootView(
                        appState: appState,
                        appEnvironment: appEnvironment,
                        lecturesListViewModel: lecturesListViewModel
                    )
                }
            }
            .preferredColorScheme(.light)
            .environmentObject(subscriptionManager)
            .environment(appState)
            .environment(\.locale, appState.locale)
            .environment(\.layoutDirection, appState.selectedLanguage.layoutDirection)
            .id(appState.selectedLanguage.id)
        }
    }
}
