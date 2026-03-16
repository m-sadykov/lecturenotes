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
    
    init() {
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: "test_WiOttVRhcRMJqvByDuPjYzOGNOy")
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                LectureNotesRootView()
                    .preferredColorScheme(.light)
            }
        }
    }
}
