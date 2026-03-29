import FirebaseAnalytics
import Foundation

final class AppAnalyticsService {
    private let isEnabled: Bool

    init(isEnabled: Bool? = nil) {
        self.isEnabled = isEnabled ?? (ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1")
    }

    func track(_ event: AppAnalyticsEvent) {
        guard isEnabled else {
            return
        }

        Analytics.logEvent(event.name, parameters: event.parameters)
    }

    func setUserProperties(
        plan: AppUserPlan?,
        language: AppLanguage,
        isPremium: Bool
    ) {
        guard isEnabled else {
            return
        }

        Analytics.setUserProperty(plan?.rawValue, forName: "plan")
        Analytics.setUserProperty(language.rawValue, forName: "selected_language")
        Analytics.setUserProperty(isPremium ? "true" : "false", forName: "is_premium")
    }
}
