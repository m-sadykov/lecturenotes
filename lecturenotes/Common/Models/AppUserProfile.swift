import Foundation

enum AppUserPlan: String, CaseIterable, Codable, Identifiable {
    case freemium
    case premium
    case pro

    var id: Self { self }

    var title: String {
        switch self {
        case .freemium:
            String(appLocalized: "Freemium")
        case .premium:
            String(appLocalized: "Premium")
        case .pro:
            String(appLocalized: "Pro")
        }
    }

    /// Whether the plan includes importing lectures from YouTube links.
    /// Freemium users can open the import sheet but are sent to the paywall on submit.
    var canImportFromYouTube: Bool {
        switch self {
        case .freemium:
            false
        case .premium, .pro:
            true
        }
    }

    /// Whether the plan includes generating a new set of flashcards or quiz questions
    /// for a lecture. The backend enforces the same rule and a daily per-lecture limit.
    var canRegenerateStudyItems: Bool {
        switch self {
        case .freemium:
            false
        case .premium, .pro:
            true
        }
    }

    var processingLimitTotalCount: Int? {
        switch self {
        case .freemium:
            5
        case .premium, .pro:
            nil
        }
    }

    var recordingLimitDuration: Duration {
        switch self {
        case .freemium:
            .seconds(5 * 60)
        case .premium:
            .seconds(100 * 60)
        case .pro:
            .seconds(4 * 60 * 60)
        }
    }

    var recordingLimitSeconds: Double {
        recordingLimitDuration.timeInterval
    }

    var audioImportLimitDuration: Duration {
        switch self {
        case .freemium:
            .seconds(5 * 60)
        case .premium:
            .seconds(100 * 60)
        case .pro:
            .seconds(4 * 60 * 60)
        }
    }

    var audioImportLimitSeconds: Double {
        audioImportLimitDuration.timeInterval
    }

    var pdfPageLimit: Int {
        switch self {
        case .freemium:
            5
        case .premium:
            50
        case .pro:
            200
        }
    }
}

struct AppUserProcessingQuota: Hashable, Codable {
    var totalCount: Int
    var usedCount: Int
    var remainingCount: Int
    var isUnlimited: Bool

    static func make(plan: AppUserPlan, usedCount: Int = 0) -> AppUserProcessingQuota {
        let normalizedUsedCount = max(usedCount, 0)

        if let totalCount = plan.processingLimitTotalCount {
            let clampedUsedCount = min(normalizedUsedCount, totalCount)
            return AppUserProcessingQuota(
                totalCount: totalCount,
                usedCount: clampedUsedCount,
                remainingCount: max(totalCount - clampedUsedCount, 0),
                isUnlimited: false
            )
        }

        return AppUserProcessingQuota(
            totalCount: -1,
            usedCount: normalizedUsedCount,
            remainingCount: -1,
            isUnlimited: true
        )
    }
}

struct AppUserProfile: Identifiable, Hashable, Codable {
    let id: String
    var plan: AppUserPlan
    var processingQuota: AppUserProcessingQuota

    init(
        id: String,
        plan: AppUserPlan,
        processingQuota: AppUserProcessingQuota
    ) {
        self.id = id
        self.plan = plan
        self.processingQuota = processingQuota
    }

    var recordingLimitDuration: Duration {
        plan.recordingLimitDuration
    }

    var recordingLimitSeconds: Double {
        plan.recordingLimitSeconds
    }

    var audioImportLimitDuration: Duration {
        plan.audioImportLimitDuration
    }

    var audioImportLimitSeconds: Double {
        plan.audioImportLimitSeconds
    }

    var pdfPageLimit: Int {
        plan.pdfPageLimit
    }

    var canStartProcessing: Bool {
        processingQuota.isUnlimited || processingQuota.remainingCount > 0
    }

    static func makeDefault(id: String) -> AppUserProfile {
        let plan: AppUserPlan = .freemium
        return AppUserProfile(
            id: id,
            plan: plan,
            processingQuota: .make(plan: plan)
        )
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        TimeInterval(components.seconds) + (TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000)
    }
}
