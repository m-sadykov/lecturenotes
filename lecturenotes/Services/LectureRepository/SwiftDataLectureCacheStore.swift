import Foundation
import SwiftData

@MainActor
final class SwiftDataLectureCacheStore {
    private let modelContainer: ModelContainer
    private let audioStore: LectureLocalAudioStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(modelContainer: ModelContainer, audioStore: LectureLocalAudioStore = LectureLocalAudioStore()) {
        self.modelContainer = modelContainer
        self.audioStore = audioStore
    }

    func fetchLectures(for userID: String) -> [Lecture] {
        let descriptor = FetchDescriptor<CachedLectureRecord>(
            predicate: #Predicate { record in
                record.ownerUserID == userID
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        let records = (try? modelContext.fetch(descriptor)) ?? []
        var resolver = LectureAudioFileResolver(audioStore: audioStore)
        return records.compactMap { decodeLecture(from: $0, resolver: &resolver) }
    }

    func fetchLectures(for userID: String, remoteIDs: [String]) -> [Lecture] {
        guard !remoteIDs.isEmpty else {
            return []
        }

        let descriptor = FetchDescriptor<CachedLectureRecord>(
            predicate: #Predicate { record in
                record.ownerUserID == userID
            }
        )

        let remoteIDSet = Set(remoteIDs)
        let records = (try? modelContext.fetch(descriptor)) ?? []
        var resolver = LectureAudioFileResolver(audioStore: audioStore)
        let lecturesByRemoteID = records.reduce(into: [String: Lecture]()) { result, record in
            guard remoteIDSet.contains(record.remoteID),
                  let lecture = decodeLecture(from: record, resolver: &resolver) else {
                return
            }

            result[record.remoteID] = lecture
        }

        return remoteIDs.compactMap { lecturesByRemoteID[$0] }
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

        var resolver = LectureAudioFileResolver(audioStore: audioStore)
        return decodeLecture(from: record, resolver: &resolver)
    }

    func cachedLectureMap(for userID: String) -> [String: Lecture] {
        let descriptor = FetchDescriptor<CachedLectureRecord>(
            predicate: #Predicate { record in
                record.ownerUserID == userID
            }
        )

        let records = (try? modelContext.fetch(descriptor)) ?? []
        var resolver = LectureAudioFileResolver(audioStore: audioStore)
        return records.reduce(into: [String: Lecture]()) { result, record in
            if let lecture = decodeLecture(from: record, resolver: &resolver) {
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
                title: lecture.title,
                summaryShort: lecture.summaryShort,
                transcriptPreview: Self.transcriptPreview(for: lecture),
                folderRemoteID: lecture.folderID?.uuidString,
                createdAt: lecture.createdAt,
                payload: Data()
            )

        record.title = lecture.title
        record.summaryShort = lecture.summaryShort
        record.transcriptPreview = Self.transcriptPreview(for: lecture)
        record.folderRemoteID = lecture.folderID?.uuidString
        record.createdAt = lecture.createdAt
        var resolver = LectureAudioFileResolver(audioStore: audioStore)
        try apply(lecture, to: record, resolver: &resolver)

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
        var resolver = LectureAudioFileResolver(audioStore: audioStore)

        for lecture in lectures {
            let remoteID = lecture.id.uuidString
            let record = existingByRemoteID[remoteID] ??
                CachedLectureRecord(
                    ownerUserID: userID,
                    remoteID: remoteID,
                    title: lecture.title,
                    summaryShort: lecture.summaryShort,
                    transcriptPreview: Self.transcriptPreview(for: lecture),
                    folderRemoteID: lecture.folderID?.uuidString,
                    createdAt: lecture.createdAt,
                    payload: Data()
                )

            record.title = lecture.title
            record.summaryShort = lecture.summaryShort
            record.transcriptPreview = Self.transcriptPreview(for: lecture)
            record.folderRemoteID = lecture.folderID?.uuidString
            record.createdAt = lecture.createdAt
            try apply(lecture, to: record, resolver: &resolver)

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

    /// Decodes a cached lecture and points `audioURL` at its file in the
    /// current recordings directory, or `nil` when no local file exists.
    private func decodeLecture(from record: CachedLectureRecord, resolver: inout LectureAudioFileResolver) -> Lecture? {
        guard var lecture = try? decoder.decode(Lecture.self, from: record.payload) else {
            return nil
        }

        // Payloads written before `audioFileName` existed carry an absolute URL
        // that may point into an earlier app container; keep only its file name.
        let legacyFileName = audioStore.fileName(for: lecture.audioURL)
        lecture.audioURL = audioStore.existingFileURL(named: record.audioFileName)
            ?? audioStore.existingFileURL(named: legacyFileName)
            ?? audioStore.existingFileURL(named: resolver.lectureIDNamedFileName(for: lecture))
        return lecture
    }

    /// Writes a lecture into a record without ever dropping a known local audio file.
    ///
    /// A `nil` `audioURL` only means the caller does not know the local file:
    /// lectures rebuilt from a Firestore snapshot before `saveLecture` reaches
    /// the cache, or stale in-memory copies. The local link is cleared only by
    /// deleting the record.
    private func apply(_ lecture: Lecture, to record: CachedLectureRecord, resolver: inout LectureAudioFileResolver) throws {
        let legacyFileName = record.audioFileName == nil ? legacyAudioFileName(in: record.payload) : nil
        let knownFileName = audioStore.fileName(for: lecture.audioURL) ?? record.audioFileName ?? legacyFileName
        record.audioFileName = knownFileName ?? resolver.lectureIDNamedFileName(for: lecture)

        var payloadLecture = lecture
        payloadLecture.audioURL = nil
        record.payload = try encoder.encode(payloadLecture)
    }

    private func legacyAudioFileName(in payload: Data) -> String? {
        guard !payload.isEmpty, let lecture = try? decoder.decode(Lecture.self, from: payload) else {
            return nil
        }

        return audioStore.fileName(for: lecture.audioURL)
    }

    private func saveContext() throws {
        if modelContext.hasChanges {
            try modelContext.save()
        }
    }

    private static func transcriptPreview(for lecture: Lecture) -> String {
        let transcript = lecture.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else {
            return ""
        }

        let previewLimit = 1_500
        guard transcript.count > previewLimit else {
            return transcript
        }

        let endIndex = transcript.index(transcript.startIndex, offsetBy: previewLimit)
        return String(transcript[..<endIndex])
    }
}
