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

final class SubscriptionManager: NSObject, ObservableObject {
    static let premiumEntitlementIdentifier = "Lectra: Lecture Notes AI Pro"

    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var isPremium: Bool = false

    private var started = false
    private var cancellables = Set<AnyCancellable>()
//    private let userService = UserService.shared

    func start() {
        guard !started else { return }
        started = true

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
        do {
            let info = try await Purchases.shared.customerInfo()
            await MainActor.run {
                self.apply(customerInfo: info)
            }
        } catch {
            // Intentionally ignore refresh errors for now (e.g. no network).
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
        self.isPremium = customerInfo.entitlements[Self.premiumEntitlementIdentifier]?.isActive == true
//        userService.updateSubscriptionStatus(isSubscribed: isPremium)
    }
}

extension SubscriptionManager: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.apply(customerInfo: customerInfo)
        }
    }
}
