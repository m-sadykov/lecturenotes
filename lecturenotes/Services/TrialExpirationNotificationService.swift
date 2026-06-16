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

    static func activeTrial(in customerInfo: CustomerInfo) -> ActiveTrial? {
        let entitlementChecks: [(String, AppUserPlan)] = [
            (SubscriptionManager.proEntitlementIdentifier, .pro),
            (SubscriptionManager.premiumEntitlementIdentifier, .premium),
        ]

        for (entitlementIdentifier, plan) in entitlementChecks {
            guard let entitlement = customerInfo.entitlements[entitlementIdentifier],
                  entitlement.isActive,
                  entitlement.periodType == .trial,
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
        leadTime: TimeInterval = reminderLeadTime
    ) -> Date? {
        let reminderDate = expirationDate.addingTimeInterval(-leadTime)
        guard reminderDate > now else { return nil }
        return reminderDate
    }
}

@MainActor
final class TrialExpirationNotificationService {
    static let notificationIdentifier = "subscription.trial-expiration-reminder"

    private let notificationCenter: UNUserNotificationCenter
    private let crashReportingService: CrashReportingService?

    init(
        notificationCenter: UNUserNotificationCenter = .current(),
        crashReportingService: CrashReportingService? = nil
    ) {
        self.notificationCenter = notificationCenter
        self.crashReportingService = crashReportingService
    }

    func sync(with customerInfo: CustomerInfo) async {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }

        guard let activeTrial = TrialExpirationReminderSchedule.activeTrial(in: customerInfo) else {
            await cancelReminder()
            return
        }

        guard let reminderDate = TrialExpirationReminderSchedule.reminderDate(
            expirationDate: activeTrial.expirationDate
        ) else {
            await cancelReminder()
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

        await scheduleReminder(at: reminderDate, plan: activeTrial.plan)
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

    private func scheduleReminder(at date: Date, plan: AppUserPlan) async {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: [Self.notificationIdentifier]
        )

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Your trial ends tomorrow")
        content.body = String(
            localized: "Subscribe to keep your \(plan.title) features."
        )
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.notificationIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            crashReportingService?.breadcrumb(
                "trial_reminder_scheduled",
                metadata: [
                    "plan": plan.rawValue,
                    "reminder_date": ISO8601DateFormatter().string(from: date),
                ]
            )
        } catch {
            crashReportingService?.breadcrumb(
                "trial_reminder_schedule_failed",
                metadata: [
                    "plan": plan.rawValue,
                    "error": error.localizedDescription,
                ]
            )
        }
    }
}
