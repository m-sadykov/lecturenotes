import Foundation

extension Lecture {
    func matchesSearchQuery(_ query: String) -> Bool {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return true
        }

        return title.localizedStandardContains(query)
            || summaryShort.localizedStandardContains(query)
            || summaryLong.localizedStandardContains(query)
            || transcript.localizedStandardContains(query)
    }
}
