import FirebaseAuth
import FirebaseFirestore
import Foundation
import Observation

@MainActor
@Observable
final class FirebaseUserProfileService {
    private let authService: FirebaseAuthService
    private let firestore: Firestore
    private(set) var currentProfile: AppUserProfile?

    init(
        authService: FirebaseAuthService,
        firestore: Firestore? = nil
    ) {
        self.authService = authService
        self.firestore = firestore ?? Firestore.firestore()
    }

    func prepareCurrentUserProfile() async {
        do {
            _ = try await ensureCurrentUserProfile()
        } catch {
            // Best-effort profile bootstrap. The app can still function locally.
        }
    }

    func ensureCurrentUserProfile() async throws -> AppUserProfile {
        let user = try await authService.ensureSignedIn()
        let documentReference = userDocumentReference(userID: user.uid)
        let snapshot = try await getDocument(at: documentReference)

        if let data = snapshot.data(), !data.isEmpty {
            let normalizedProfile = normalizedProfile(userID: user.uid, data: data)
            try await setData(
                makeDocumentData(for: normalizedProfile),
                at: documentReference,
                merge: true
            )
            currentProfile = normalizedProfile
            return normalizedProfile
        }

        let profile = AppUserProfile.makeDefault(id: user.uid)
        try await setData(
            makeDocumentData(for: profile, includeCreatedAt: true),
            at: documentReference,
            merge: true
        )
        currentProfile = profile
        return profile
    }

    func syncSubscriptionPlan(_ plan: AppUserPlan) async {
        do {
            let currentProfile = try await ensureCurrentUserProfile()
            let targetQuota = AppUserProcessingQuota.make(
                plan: plan,
                usedCount: currentProfile.processingQuota.usedCount
            )

            guard currentProfile.plan != plan ||
                    currentProfile.processingQuota.totalCount != targetQuota.totalCount ||
                    currentProfile.processingQuota.isUnlimited != targetQuota.isUnlimited ||
                    currentProfile.recordingLimitSeconds != plan.recordingLimitSeconds ||
                    currentProfile.audioImportLimitSeconds != plan.audioImportLimitSeconds ||
                    currentProfile.pdfPageLimit != plan.pdfPageLimit else {
                return
            }

            let updatedProfile = AppUserProfile(
                id: currentProfile.id,
                plan: plan,
                processingQuota: targetQuota
            )

            try await setData(
                makeDocumentData(for: updatedProfile, includeSubscriptionUpdatedAt: true),
                at: userDocumentReference(userID: currentProfile.id),
                merge: true
            )
            self.currentProfile = updatedProfile
        } catch {
            // Subscription state should still update locally even if backend sync fails.
        }
    }

    private func normalizedProfile(userID: String, data: [String: Any]) -> AppUserProfile {
        let storedPlan = AppUserPlan(rawValue: data["plan"] as? String ?? "") ?? .freemium
        let isUnlimited = (data["processingLimitIsUnlimited"] as? Bool) ?? (storedPlan.processingLimitTotalCount == nil)
        let usedCount = Self.intValue(for: "processingLimitUsedCount", in: data)
        let totalCount = Self.intValue(for: "processingLimitTotalCount", in: data)
        let remainingCount = Self.intValue(for: "processingLimitRemainingCount", in: data)

        let normalizedQuota: AppUserProcessingQuota
        if isUnlimited {
            normalizedQuota = AppUserProcessingQuota(
                totalCount: -1,
                usedCount: max(usedCount ?? 0, 0),
                remainingCount: -1,
                isUnlimited: true
            )
        } else if let totalCount {
            let clampedUsedCount = min(max(usedCount ?? 0, 0), totalCount)
            normalizedQuota = AppUserProcessingQuota(
                totalCount: totalCount,
                usedCount: clampedUsedCount,
                remainingCount: remainingCount ?? max(totalCount - clampedUsedCount, 0),
                isUnlimited: false
            )
        } else {
            normalizedQuota = .make(plan: storedPlan)
        }

        return AppUserProfile(
            id: userID,
            plan: storedPlan,
            processingQuota: normalizedQuota
        )
    }

    private func makeDocumentData(
        for profile: AppUserProfile,
        includeCreatedAt: Bool = false,
        includeSubscriptionUpdatedAt: Bool = false
    ) -> [String: Any] {
        var data: [String: Any] = [
            "id": profile.id,
            "plan": profile.plan.rawValue,
            "processingLimitTotalCount": profile.processingQuota.totalCount,
            "processingLimitUsedCount": profile.processingQuota.usedCount,
            "processingLimitRemainingCount": profile.processingQuota.remainingCount,
            "processingLimitIsUnlimited": profile.processingQuota.isUnlimited,
            "recordingLimitSec": profile.recordingLimitSeconds,
            "audioImportLimitSec": profile.audioImportLimitSeconds,
            "pdfPageLimit": profile.pdfPageLimit,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if includeCreatedAt {
            data["createdAt"] = FieldValue.serverTimestamp()
        }

        if includeSubscriptionUpdatedAt {
            data["subscriptionUpdatedAt"] = FieldValue.serverTimestamp()
        }

        return data
    }

    private func userDocumentReference(userID: String) -> DocumentReference {
        firestore.collection("users").document(userID)
    }

    private func setData(
        _ data: [String: Any],
        at documentReference: DocumentReference,
        merge: Bool = false
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            documentReference.setData(data, merge: merge) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func getDocument(at documentReference: DocumentReference) async throws -> DocumentSnapshot {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DocumentSnapshot, Error>) in
            documentReference.getDocument { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: FirebaseUserProfileServiceError.missingUserDocument)
                }
            }
        }
    }

    private static func intValue(for key: String, in data: [String: Any]) -> Int? {
        if let value = data[key] as? Int {
            return value
        }

        if let value = data[key] as? Double {
            return Int(value)
        }

        return nil
    }
}

enum FirebaseUserProfileServiceError: LocalizedError {
    case missingUserDocument

    var errorDescription: String? {
        switch self {
        case .missingUserDocument:
            "User profile is unavailable."
        }
    }
}
