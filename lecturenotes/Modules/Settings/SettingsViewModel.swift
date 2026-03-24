import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class SettingsViewModel {
    var selectedLanguage: String {
        didSet {
            guard languages.contains(selectedLanguage) else {
                selectedLanguage = Self.defaultLanguage
                return
            }

            userDefaults.set(selectedLanguage, forKey: Self.selectedLanguageKey)
        }
    }

    var deleteAudioAfterProcessing: Bool {
        didSet {
            userDefaults.set(deleteAudioAfterProcessing, forKey: Self.deleteAudioAfterProcessingKey)
        }
    }

    var isRestoringPurchases = false

    let languages: [String]

    private let authService: FirebaseAuthService?
    private let userProfileService: FirebaseUserProfileService?
    private let userDefaults: UserDefaults

    private static let defaultLanguage = "English"
    private static let supportedLanguages = ["English", "Русский", "Қазақша"]
    private static let selectedLanguageKey = "settings.selectedLanguage"
    private static let deleteAudioAfterProcessingKey = "settings.deleteAudioAfterProcessing"

    init(
        authService: FirebaseAuthService? = nil,
        userProfileService: FirebaseUserProfileService? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.authService = authService
        self.userProfileService = userProfileService
        self.userDefaults = userDefaults
        self.languages = Self.supportedLanguages

        let storedLanguage = userDefaults.string(forKey: Self.selectedLanguageKey)
        let resolvedLanguage = storedLanguage ?? Self.defaultLanguage
        self.selectedLanguage = Self.supportedLanguages.contains(resolvedLanguage) ? resolvedLanguage : Self.defaultLanguage
        self.deleteAudioAfterProcessing = userDefaults.bool(forKey: Self.deleteAudioAfterProcessingKey)
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
            return "Purchases restored."
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
