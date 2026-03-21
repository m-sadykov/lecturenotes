import Foundation
import SwiftData

actor SwiftDataLectureSearchStore {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func searchLectureIDs(matching query: String, for userID: String) -> [String] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return []
        }

        let descriptor = FetchDescriptor<CachedLectureRecord>(
            predicate: #Predicate { record in
                record.ownerUserID == userID
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        let modelContext = ModelContext(modelContainer)
        let records = (try? modelContext.fetch(descriptor)) ?? []

        return records.compactMap { record in
            guard record.matchesSearchQuery(trimmedQuery) else {
                return nil
            }

            return record.remoteID
        }
    }
}

private extension CachedLectureRecord {
    func matchesSearchQuery(_ query: String) -> Bool {
        title.localizedStandardContains(query)
            || summaryShort.localizedStandardContains(query)
            || transcriptPreview.localizedStandardContains(query)
    }
}
