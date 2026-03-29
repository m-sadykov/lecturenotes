import FirebaseCrashlytics
import Foundation

final class CrashReportingService {
    private let isEnabled: Bool

    init(isEnabled: Bool? = nil) {
        self.isEnabled = isEnabled ?? (ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1")

        guard self.isEnabled else {
            return
        }

        setCustomValue(Self.buildNumber, forKey: "build_number")
    }

    func breadcrumb(_ message: String, metadata: [String: Any] = [:]) {
        guard isEnabled else {
            return
        }

        let sanitizedMessage = Self.sanitized(message)
        setCustomValue(sanitizedMessage, forKey: "last_breadcrumb")
        Crashlytics.crashlytics().log(renderBreadcrumb(message: sanitizedMessage, metadata: metadata))
    }

    func setUserContext(
        plan: AppUserPlan?,
        language: AppLanguage,
        isPremium: Bool
    ) {
        setCustomValue(plan?.rawValue ?? "", forKey: "plan")
        setCustomValue(language.rawValue, forKey: "selected_language")
        setCustomValue(isPremium, forKey: "is_premium")
    }

    func setCurrentScreen(_ screen: String) {
        setCustomValue(screen, forKey: "current_screen")
    }

    func setCurrentFlow(_ flow: String) {
        setCustomValue(flow, forKey: "current_flow")
    }

    func setLectureContext(_ lecture: Lecture?) {
        setCustomValue(lecture?.id.uuidString ?? "", forKey: "lecture_id")
        setCustomValue(lecture?.sourceType.rawValue ?? "", forKey: "lecture_source_type")
        setCustomValue(lecture?.status.rawValue ?? "", forKey: "lecture_status")
    }

    func setProcessingStage(_ stage: String) {
        setCustomValue(stage, forKey: "processing_stage")
    }

    func setCustomValue(_ value: Any, forKey key: String) {
        guard isEnabled else {
            return
        }

        Crashlytics.crashlytics().setCustomValue(serializedValue(value), forKey: key)
    }

    func setCustomValues(_ values: [String: Any]) {
        guard isEnabled else {
            return
        }

        for (key, value) in values {
            setCustomValue(value, forKey: key)
        }
    }

    func recordNonFatal(
        _ error: Error,
        reason: String,
        metadata: [String: Any] = [:]
    ) {
        guard isEnabled else {
            return
        }

        breadcrumb(reason, metadata: metadata)
        setCustomValues(metadata)
        Crashlytics.crashlytics().record(error: error)
    }
}

private extension CrashReportingService {
    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
    }

    static func sanitized(_ value: String) -> String {
        String(value.prefix(96))
    }

    func renderBreadcrumb(message: String, metadata: [String: Any]) -> String {
        guard !metadata.isEmpty else {
            return message
        }

        let serializedMetadata = metadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\(serializedValue($0.value))" }
            .joined(separator: ", ")
        return "\(message) | \(serializedMetadata)"
    }

    func serializedValue(_ value: Any) -> Any {
        switch value {
        case let string as String:
            return Self.sanitized(string)
        case let bool as Bool:
            return bool
        case let int as Int:
            return int
        case let double as Double:
            return double
        case let float as Float:
            return Double(float)
        case let uuid as UUID:
            return uuid.uuidString
        case let date as Date:
            return date.ISO8601Format()
        case let array as [Any]:
            return array.map { String(describing: $0) }.joined(separator: ",")
        default:
            return Self.sanitized(String(describing: value))
        }
    }
}
