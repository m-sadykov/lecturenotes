import Foundation
import RevenueCat
import UserNotifications

extension Notification.Name {
    static let trialExpirationReminderTapped = Notification.Name("trialExpirationReminderTapped")
}

struct TrialExpirationReminderSchedule {
    struct ActiveTrial: Equatable {
        let plan: AppUserPlan
        let expirationDate: Date
    }

    static let reminderLeadTime: TimeInterval = 24 * 60 * 60
    static let minimumFallbackLeadTime: TimeInterval = 60 * 60

    #if DEBUG
    /// Short lead time for StoreKit local testing so reminders fire within the trial window.
    static let debugReminderLeadTime: TimeInterval = 2 * 60
    #endif

    static func isIntroductoryPeriod(_ entitlement: EntitlementInfo) -> Bool {
        switch entitlement.periodType {
        case .trial, .intro:
            true
        default:
            false
        }
    }

    static func activeTrial(in customerInfo: CustomerInfo) -> ActiveTrial? {
        let entitlementChecks: [(String, AppUserPlan)] = [
            (SubscriptionManager.proEntitlementIdentifier, .pro),
            (SubscriptionManager.premiumEntitlementIdentifier, .premium),
        ]

        for (entitlementIdentifier, plan) in entitlementChecks {
            guard let entitlement = customerInfo.entitlements[entitlementIdentifier],
                  entitlement.isActive,
                  isIntroductoryPeriod(entitlement),
                  let expirationDate = entitlement.expirationDate else {
                continue
            }

            return ActiveTrial(plan: plan, expirationDate: expirationDate)
        }

        return nil
    }

    static func reminderDate(
        expirationDate: Date,
        now: Date = .now,
        leadTime: TimeInterval? = nil
    ) -> Date? {
        let timeUntilExpiration = expirationDate.timeIntervalSince(now)
        guard timeUntilExpiration > 0 else { return nil }

        #if DEBUG
        if timeUntilExpiration <= 7 * 24 * 60 * 60 {
            let soonReminderDate = now.addingTimeInterval(debugReminderLeadTime)
            if soonReminderDate < expirationDate {
                return soonReminderDate
            }
        }
        #endif

        let resolvedLeadTime = leadTime ?? reminderLeadTime
        let idealReminderDate = expirationDate.addingTimeInterval(-resolvedLeadTime)
        if idealReminderDate > now {
            return idealReminderDate
        }

        let fallbackReminderDate = expirationDate.addingTimeInterval(-minimumFallbackLeadTime)
        if fallbackReminderDate > now {
            return fallbackReminderDate
        }

        return nil
    }
}

@MainActor
final class TrialExpirationNotificationService {
    static let notificationIdentifier = "subscription.trial-expiration-reminder"
    static let scheduledExpirationUserInfoKey = "trialExpirationTimestamp"
    private static let scheduledExpirationDefaultsKey = "trialReminder.scheduledExpiration"

    private let notificationCenter: UNUserNotificationCenter
    private let crashReportingService: CrashReportingService?
    private let userDefaults: UserDefaults

    init(
        notificationCenter: UNUserNotificationCenter = .current(),
        crashReportingService: CrashReportingService? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.notificationCenter = notificationCenter
        self.crashReportingService = crashReportingService
        self.userDefaults = userDefaults
    }

    static func expirationMarker(for expirationDate: Date) -> String {
        String(Int(expirationDate.timeIntervalSince1970))
    }

    static func markReminderHandled(
        for expirationDate: Date,
        userDefaults: UserDefaults = .standard
    ) {
        userDefaults.set(
            expirationMarker(for: expirationDate),
            forKey: scheduledExpirationDefaultsKey
        )
    }

    static func handleDeliveredNotification(_ notification: UNNotification) {
        guard notification.request.identifier == notificationIdentifier,
              let marker = notification.request.content.userInfo[scheduledExpirationUserInfoKey] as? String else {
            return
        }

        UserDefaults.standard.set(marker, forKey: scheduledExpirationDefaultsKey)
    }

    private func hasScheduledReminder(for expirationDate: Date) -> Bool {
        userDefaults.string(forKey: Self.scheduledExpirationDefaultsKey)
            == Self.expirationMarker(for: expirationDate)
    }

    private func clearScheduledReminderMarker() {
        userDefaults.removeObject(forKey: Self.scheduledExpirationDefaultsKey)
    }

    func sync(with customerInfo: CustomerInfo) async {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }

        guard let activeTrial = TrialExpirationReminderSchedule.activeTrial(in: customerInfo) else {
            await cancelReminder()
            clearScheduledReminderMarker()
            crashReportingService?.breadcrumb("trial_reminder_cleared_no_active_trial")
            return
        }

        if hasScheduledReminder(for: activeTrial.expirationDate) {
            crashReportingService?.breadcrumb(
                "trial_reminder_already_scheduled",
                metadata: [
                    "plan": activeTrial.plan.rawValue,
                    "expiration_date": ISO8601DateFormatter().string(from: activeTrial.expirationDate),
                ]
            )

            #if DEBUG
            print("[TrialReminder] Skipping duplicate schedule for the same trial expiration")
            #endif
            return
        }

        guard let reminderDate = TrialExpirationReminderSchedule.reminderDate(
            expirationDate: activeTrial.expirationDate
        ) else {
            await cancelReminder()
            Self.markReminderHandled(for: activeTrial.expirationDate, userDefaults: userDefaults)
            crashReportingService?.breadcrumb(
                "trial_reminder_skipped_too_late",
                metadata: [
                    "plan": activeTrial.plan.rawValue,
                    "expiration_date": ISO8601DateFormatter().string(from: activeTrial.expirationDate),
                ]
            )
            return
        }

        guard await ensureAuthorization() else {
            crashReportingService?.breadcrumb(
                "trial_reminder_not_authorized",
                metadata: ["plan": activeTrial.plan.rawValue]
            )
            return
        }

        await scheduleReminder(
            at: reminderDate,
            plan: activeTrial.plan,
            expirationDate: activeTrial.expirationDate
        )
    }

    func cancelReminder() async {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: [Self.notificationIdentifier]
        )
    }

    private func ensureAuthorization() async -> Bool {
        let settings = await notificationCenter.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await notificationCenter.requestAuthorization(options: [.alert, .sound])
            } catch {
                crashReportingService?.breadcrumb(
                    "trial_reminder_authorization_failed",
                    metadata: ["error": error.localizedDescription]
                )
                return false
            }
        @unknown default:
            return false
        }
    }

    private func scheduleReminder(at date: Date, plan: AppUserPlan, expirationDate: Date) async {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: [Self.notificationIdentifier]
        )

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Your trial ends tomorrow")
        content.body = String(
            localized: "Subscribe to keep your \(plan.title) features."
        )
        content.sound = .default
        content.userInfo = [
            Self.scheduledExpirationUserInfoKey: Self.expirationMarker(for: expirationDate),
        ]

        let interval = max(date.timeIntervalSinceNow, 60)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.notificationIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            Self.markReminderHandled(for: expirationDate, userDefaults: userDefaults)
            crashReportingService?.breadcrumb(
                "trial_reminder_scheduled",
                metadata: [
                    "plan": plan.rawValue,
                    "reminder_date": ISO8601DateFormatter().string(from: date),
                    "expiration_date": ISO8601DateFormatter().string(from: expirationDate),
                    "fire_in_seconds": String(format: "%.0f", interval),
                    "period_type": "intro_or_trial",
                ]
            )

            #if DEBUG
            let pending = await notificationCenter.pendingNotificationRequests()
            if let scheduled = pending.first(where: { $0.identifier == Self.notificationIdentifier }) {
                print(
                    "[TrialReminder] Scheduled for \(date.formatted()) " +
                    "(fires in \(Int(interval))s). Trigger: \(String(describing: scheduled.trigger))"
                )
            } else {
                print("[TrialReminder] WARNING: request added but not found in pending queue")
            }
            #endif
        } catch {
            crashReportingService?.breadcrumb(
                "trial_reminder_schedule_failed",
                metadata: [
                    "plan": plan.rawValue,
                    "error": error.localizedDescription,
                ]
            )

            #if DEBUG
            print("[TrialReminder] Schedule failed: \(error.localizedDescription)")
            #endif
        }
    }
}
