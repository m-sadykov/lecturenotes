//
//  SubscriptionManager.swift
//  lecturenotes
//
//  Created by Marat Sadykov on 15.03.2026.
//

import Foundation
import Combine
import RevenueCat
import UIKit

@MainActor
final class SubscriptionManager: NSObject, ObservableObject {
    static let premiumEntitlementIdentifier = "com.marat.lecturenotesai_premium"
    static let proEntitlementIdentifier = "com.marat.lecturenotesai_pro"

    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var currentPlan: AppUserPlan = .freemium
    @Published private(set) var isPremium: Bool = false

    private let userProfileService: FirebaseUserProfileService?
    private let crashReportingService: CrashReportingService?
    private var started = false
    private var cancellables = Set<AnyCancellable>()

    init(
        userProfileService: FirebaseUserProfileService? = nil,
        crashReportingService: CrashReportingService? = nil
    ) {
        self.userProfileService = userProfileService
        self.crashReportingService = crashReportingService
        super.init()
    }

    func start() {
        guard !started else { return }
        started = true
        crashReportingService?.breadcrumb("subscription_manager_started")

        // Avoid running RevenueCat logic inside SwiftUI previews.
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return
        }

        Purchases.shared.delegate = self

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.refresh() }
            }
            .store(in: &cancellables)

        Task {
            await refresh()
        }

        Task {
            for await info in Purchases.shared.customerInfoStream {
                await MainActor.run {
                    self.apply(customerInfo: info)
                }
            }
        }
    }

    func refresh() async {
        crashReportingService?.breadcrumb("subscription_refresh_started")
        do {
            let info = try await Purchases.shared.customerInfo()
            await MainActor.run {
                self.apply(customerInfo: info)
            }
        } catch {
            crashReportingService?.breadcrumb(
                "subscription_refresh_failed",
                metadata: [
                    "error": error.localizedDescription,
                ]
            )
        }
    }

    func restorePurchases() async throws -> CustomerInfo {
        let info = try await Purchases.shared.restorePurchases()
        await MainActor.run {
            self.apply(customerInfo: info)
        }
        return info
    }

    func update(from customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.apply(customerInfo: customerInfo)
        }
    }

    @MainActor
    private func apply(customerInfo: CustomerInfo) {
        self.customerInfo = customerInfo
        let resolvedPlan = resolvePlan(from: customerInfo)
        self.currentPlan = resolvedPlan
        self.isPremium = resolvedPlan != .freemium

        let currentPlan = self.currentPlan
        Task {
            await userProfileService?.syncSubscriptionPlan(currentPlan)
        }
        crashReportingService?.setCustomValue(resolvedPlan.rawValue, forKey: "plan")
    }

    private func resolvePlan(from customerInfo: CustomerInfo) -> AppUserPlan {
        if customerInfo.entitlements[Self.proEntitlementIdentifier]?.isActive == true {
            return .pro
        }

        if customerInfo.entitlements[Self.premiumEntitlementIdentifier]?.isActive == true {
            return .premium
        }

        return .freemium
    }
}

extension SubscriptionManager: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.apply(customerInfo: customerInfo)
        }
    }
}
