import Foundation
import SwiftData

@MainActor
final class SwiftDataLectureCacheStore {
    private let modelContainer: ModelContainer
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func fetchLectures(for userID: String) -> [Lecture] {
        let descriptor = FetchDescriptor<CachedLectureRecord>(
            predicate: #Predicate { record in
                record.ownerUserID == userID
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.compactMap(decodeLecture(from:))
    }

    func fetchFolders(for userID: String) -> [LectureFolder] {
        let descriptor = FetchDescriptor<CachedFolderRecord>(
            predicate: #Predicate { record in
                record.ownerUserID == userID
            },
            sortBy: [SortDescriptor(\.name)]
        )

        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.compactMap { record in
            guard let folderID = UUID(uuidString: record.remoteID) else {
                return nil
            }

            return LectureFolder(id: folderID, name: record.name)
        }
    }

    func fetchLecture(id: UUID, for userID: String) -> Lecture? {
        let remoteID = id.uuidString
        let descriptor = FetchDescriptor<CachedLectureRecord>(
            predicate: #Predicate { record in
                record.ownerUserID == userID && record.remoteID == remoteID
            }
        )

        let records = try? modelContext.fetch(descriptor)
        guard let record = records?.first else {
            return nil
        }

        return decodeLecture(from: record)
    }

    func cachedLectureMap(for userID: String) -> [String: Lecture] {
        let descriptor = FetchDescriptor<CachedLectureRecord>(
            predicate: #Predicate { record in
                record.ownerUserID == userID
            }
        )

        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.reduce(into: [String: Lecture]()) { result, record in
            if let lecture = decodeLecture(from: record) {
                result[record.remoteID] = lecture
            }
        }
    }

    func upsertLecture(_ lecture: Lecture, for userID: String) throws {
        let remoteID = lecture.id.uuidString
        let record = try lectureRecord(for: userID, remoteID: remoteID) ??
            CachedLectureRecord(
                ownerUserID: userID,
                remoteID: remoteID,
                createdAt: lecture.createdAt,
                payload: Data()
            )

        record.createdAt = lecture.createdAt
        record.payload = try encoder.encode(lecture)

        if record.modelContext == nil {
            modelContext.insert(record)
        }

        try saveContext()
    }

    func replaceLectures(_ lectures: [Lecture], for userID: String) throws {
        let descriptor = FetchDescriptor<CachedLectureRecord>(
            predicate: #Predicate { record in
                record.ownerUserID == userID
            }
        )

        let existingRecords = (try? modelContext.fetch(descriptor)) ?? []
        let existingByRemoteID = Dictionary(uniqueKeysWithValues: existingRecords.map { ($0.remoteID, $0) })
        let incomingRemoteIDs = Set(lectures.map { $0.id.uuidString })

        for lecture in lectures {
            let remoteID = lecture.id.uuidString
            let record = existingByRemoteID[remoteID] ??
                CachedLectureRecord(
                    ownerUserID: userID,
                    remoteID: remoteID,
                    createdAt: lecture.createdAt,
                    payload: Data()
                )

            record.createdAt = lecture.createdAt
            record.payload = try encoder.encode(lecture)

            if record.modelContext == nil {
                modelContext.insert(record)
            }
        }

        for record in existingRecords where !incomingRemoteIDs.contains(record.remoteID) {
            modelContext.delete(record)
        }

        try saveContext()
    }

    func deleteLecture(id: UUID, for userID: String) throws {
        guard let record = try lectureRecord(for: userID, remoteID: id.uuidString) else {
            return
        }

        modelContext.delete(record)
        try saveContext()
    }

    func replaceFolders(_ folders: [(folder: LectureFolder, createdAt: Date)], for userID: String) throws {
        let descriptor = FetchDescriptor<CachedFolderRecord>(
            predicate: #Predicate { record in
                record.ownerUserID == userID
            }
        )

        let existingRecords = (try? modelContext.fetch(descriptor)) ?? []
        let existingByRemoteID = Dictionary(uniqueKeysWithValues: existingRecords.map { ($0.remoteID, $0) })
        let incomingRemoteIDs = Set(folders.map { $0.folder.id.uuidString })

        for item in folders {
            let remoteID = item.folder.id.uuidString
            let record = existingByRemoteID[remoteID] ??
                CachedFolderRecord(
                    ownerUserID: userID,
                    remoteID: remoteID,
                    name: item.folder.name,
                    createdAt: item.createdAt
                )

            record.name = item.folder.name
            record.createdAt = item.createdAt

            if record.modelContext == nil {
                modelContext.insert(record)
            }
        }

        for record in existingRecords where !incomingRemoteIDs.contains(record.remoteID) {
            modelContext.delete(record)
        }

        try saveContext()
    }

    func pruneData(excluding userID: String) throws {
        let lectureDescriptor = FetchDescriptor<CachedLectureRecord>(
            predicate: #Predicate { record in
                record.ownerUserID != userID
            }
        )
        let folderDescriptor = FetchDescriptor<CachedFolderRecord>(
            predicate: #Predicate { record in
                record.ownerUserID != userID
            }
        )

        let lectureRecords = (try? modelContext.fetch(lectureDescriptor)) ?? []
        let folderRecords = (try? modelContext.fetch(folderDescriptor)) ?? []

        for record in lectureRecords {
            modelContext.delete(record)
        }

        for record in folderRecords {
            modelContext.delete(record)
        }

        try saveContext()
    }

    private var modelContext: ModelContext {
        modelContainer.mainContext
    }

    private func lectureRecord(for userID: String, remoteID: String) throws -> CachedLectureRecord? {
        let descriptor = FetchDescriptor<CachedLectureRecord>(
            predicate: #Predicate { record in
                record.ownerUserID == userID && record.remoteID == remoteID
            }
        )

        return try modelContext.fetch(descriptor).first
    }

    private func decodeLecture(from record: CachedLectureRecord) -> Lecture? {
        try? decoder.decode(Lecture.self, from: record.payload)
    }

    private func saveContext() throws {
        if modelContext.hasChanges {
            try modelContext.save()
        }
    }
}
