import SwiftUI
import RevenueCat
import FirebaseCore
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        UNUserNotificationCenter.current().delegate = self

        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        TrialExpirationNotificationService.handleDeliveredNotification(notification)
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let notification = response.notification
        TrialExpirationNotificationService.handleDeliveredNotification(notification)

        guard notification.request.identifier == TrialExpirationNotificationService.notificationIdentifier else {
            completionHandler()
            return
        }

        NotificationCenter.default.post(name: .trialExpirationReminderTapped, object: nil)
        completionHandler()
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
        let crashReportingService = CrashReportingService()
        crashReportingService.breadcrumb("app_launch_started")
        crashReportingService.breadcrumb("firebase_configured")

        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: "appl_gocyBRrDByBgmJWEJvORYtfBjUX")

        let authService = FirebaseAuthService()
        let userProfileService = FirebaseUserProfileService(authService: authService)
        let environment = AppEnvironment(
            authService: authService,
            userProfileService: userProfileService,
            crashReportingService: crashReportingService
        )
        _subscriptionManager = StateObject(
            wrappedValue: SubscriptionManager(
                userProfileService: userProfileService,
                crashReportingService: crashReportingService
            )
        )
        _appState = State(initialValue: AppState())
        _appEnvironment = State(
            initialValue: environment
        )
        _lecturesListViewModel = State(
            initialValue: LecturesListViewModel(
                repository: environment.repository,
                processingService: environment.processingService,
                userProfileService: environment.userProfileService,
                analyticsService: environment.analyticsService,
                crashReportingService: environment.crashReportingService
            )
        )
    }
    
    private func prepareStartupIfNeeded() async {
        guard !hasPreparedStartup else { return }
        hasPreparedStartup = true

        appEnvironment.crashReportingService.setCurrentFlow("app_launch")
        await updateSplashProgress(to: 0.15)
        appEnvironment.crashReportingService.breadcrumb("subscription_start_requested")
        subscriptionManager.start()

        appEnvironment.crashReportingService.breadcrumb("repository_start_started")
        await appEnvironment.repository.start()
        appEnvironment.crashReportingService.breadcrumb("repository_start_completed")
        await updateSplashProgress(to: 0.4)

        appEnvironment.crashReportingService.breadcrumb("user_profile_prepare_started")
        await appEnvironment.userProfileService?.prepareCurrentUserProfile()
        appEnvironment.crashReportingService.breadcrumb("user_profile_prepare_completed")
        await updateSplashProgress(to: 0.65)

        await subscriptionManager.refresh()
        await updateSplashProgress(to: 0.82)

        await lecturesListViewModel.load()
        appEnvironment.crashReportingService.breadcrumb("app_launch_completed")
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
            .environmentObject(subscriptionManager)
            .environment(appState)
            .environment(\.locale, appState.locale)
            .environment(\.layoutDirection, appState.selectedLanguage.layoutDirection)
            .id(appState.selectedLanguage.id)
            .onOpenURL { url in
                handleIncomingURL(url)
            }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard let action = RecordingLiveActivityRoute.action(from: url) else {
            return
        }

        switch action {
        case .show:
            return
        case .finish:
            lecturesListViewModel.finishActiveRecordingFromSystemUI()
        }
    }
}
