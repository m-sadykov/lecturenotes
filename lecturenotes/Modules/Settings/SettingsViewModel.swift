import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class SettingsViewModel {
    var isRestoringPurchases = false

    private let authService: FirebaseAuthService?
    private let userProfileService: FirebaseUserProfileService?

    init(
        authService: FirebaseAuthService? = nil,
        userProfileService: FirebaseUserProfileService? = nil
    ) {
        self.authService = authService
        self.userProfileService = userProfileService
    }

    var currentUserID: String? {
        userProfileService?.currentProfile?.id ?? authService?.currentUserID
    }

    var maskedUserID: String {
        guard let currentUserID else {
            return "Preparing..."
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
            return "Purchase restore is already in progress."
        }

        isRestoringPurchases = true
        defer {
            isRestoringPurchases = false
        }

        do {
            _ = try await subscriptionManager.restorePurchases()

            let restoredPlan = subscriptionManager.currentPlan
            guard restoredPlan != .freemium else {
                return "No active purchases were found to restore."
            }

            return "Purchases restored. Your \(restoredPlan.title) plan is active."
        } catch {
            return error.localizedDescription.isEmpty ? "Unable to restore purchases right now." : error.localizedDescription
        }
    }

    @discardableResult
    func copyUserID() -> Bool {
        guard let currentUserID else {
            return false
        }

        UIPasteboard.general.string = currentUserID
        return true
    }

    func makeSupportEmailDraft() -> SupportEmailDraft {
        let userIDText = currentUserID ?? "Unavailable"

        return SupportEmailDraft(
            recipient: SettingsSupportConfiguration.supportEmailAddress,
            subject: "LectraAI support request",
            body: """
            Hi Support,

            I need help with:


            User ID: \(userIDText)
            App version: \(Self.appVersionText)
            """
        )
    }

    private static var appVersionText: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        return "\(shortVersion) (\(buildNumber))"
    }
}
