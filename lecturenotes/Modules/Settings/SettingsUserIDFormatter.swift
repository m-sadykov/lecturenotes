import Foundation

enum SettingsUserIDFormatter {
    static func shortened(_ value: String) -> String {
        let visiblePrefixCount = min(7, value.count)
        let prefix = value.prefix(visiblePrefixCount)

        guard value.count > visiblePrefixCount else {
            return String(prefix)
        }

        return "\(prefix)..."
    }
}
