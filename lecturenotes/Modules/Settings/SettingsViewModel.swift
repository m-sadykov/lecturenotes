import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class SettingsViewModel {
    var isRestoringPurchases = false

    private let authService: FirebaseAuthService?
    private let userProfileService: FirebaseUserProfileService?
    private let analyticsService: AppAnalyticsService?
    private let crashReportingService: CrashReportingService?

    init(
        authService: FirebaseAuthService? = nil,
        userProfileService: FirebaseUserProfileService? = nil,
        analyticsService: AppAnalyticsService? = nil,
        crashReportingService: CrashReportingService? = nil
    ) {
        self.authService = authService
        self.userProfileService = userProfileService
        self.analyticsService = analyticsService
        self.crashReportingService = crashReportingService
    }

    var currentUserID: String? {
        userProfileService?.currentProfile?.id ?? authService?.currentUserID
    }

    var maskedUserID: String {
        guard let currentUserID else {
            return String(localized: "Preparing...")
        }

        return SettingsUserIDFormatter.shortened(currentUserID)
    }

    var canCopyUserID: Bool {
        currentUserID != nil
    }

    var appVersionText: String {
        Self.appVersionText
    }

    func restorePurchases(using subscriptionManager: SubscriptionManager) async -> String {
        guard !isRestoringPurchases else {
            return String(localized: "Purchase restore is already in progress.")
        }

        crashReportingService?.breadcrumb("restore_purchases_started")
        analyticsService?.track(.restorePurchasesStarted(plan: currentPlan))
        isRestoringPurchases = true
        defer {
            isRestoringPurchases = false
        }

        do {
            _ = try await subscriptionManager.restorePurchases()

            let restoredPlan = subscriptionManager.currentPlan
            guard restoredPlan != .freemium else {
                crashReportingService?.breadcrumb("restore_purchases_completed", metadata: ["result": "no_active_purchases"])
                analyticsService?.track(
                    .restorePurchasesResult(
                        result: "no_active_purchases",
                        restoredPlan: restoredPlan
                    )
                )
                return String(localized: "No active purchases were found to restore.")
            }

            crashReportingService?.breadcrumb(
                "restore_purchases_completed",
                metadata: [
                    "result": "success",
                    "restored_plan": restoredPlan.rawValue,
                ]
            )
            analyticsService?.track(
                .restorePurchasesResult(
                    result: "success",
                    restoredPlan: restoredPlan
                )
            )
            return String(localized: "Purchases restored. Your \(restoredPlan.title) plan is active.")
        } catch {
            crashReportingService?.recordNonFatal(
                error,
                reason: "restore_purchases_failed",
                metadata: [
                    "plan": currentPlan?.rawValue ?? "",
                ]
            )
            analyticsService?.track(
                .restorePurchasesResult(
                    result: "failure",
                    restoredPlan: nil
                )
            )
            return error.localizedDescription.isEmpty ? String(localized: "Unable to restore purchases right now.") : error.localizedDescription
        }
    }

    @discardableResult
    func copyUserID() -> Bool {
        guard let currentUserID else {
            return false
        }

        UIPasteboard.general.string = currentUserID
        analyticsService?.track(.userIDCopied)
        crashReportingService?.breadcrumb("user_id_copied")
        return true
    }

    func makeSupportEmailDraft() -> SupportEmailDraft {
        let userIDText = currentUserID ?? String(localized: "Unavailable")

        return SupportEmailDraft(
            recipient: SettingsSupportConfiguration.supportEmailAddress,
            subject: String(localized: "LectraAI support request"),
            body: String(
                localized: """
                Hi Support,

                I need help with:


                User ID: \(userIDText)
                App version: \(Self.appVersionText)
                """
            )
        )
    }

    private static var appVersionText: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? String(localized: "Unknown")
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? String(localized: "Unknown")
        return "\(shortVersion) (\(buildNumber))"
    }

    private var currentPlan: AppUserPlan? {
        userProfileService?.currentProfile?.plan
    }
}
