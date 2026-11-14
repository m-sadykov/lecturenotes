import Foundation
import SwiftData
import Testing
@testable import lecturenotes

@MainActor
struct LectureLocalAudioPersistenceTests {
    private let userID = "user-1"
    private let recordingsDirectory: URL
    private let audioStore: LectureLocalAudioStore
    private let modelContainer: ModelContainer
    private let cacheStore: SwiftDataLectureCacheStore

    init() throws {
        recordingsDirectory = URL.temporaryDirectory
            .appending(path: "LectureLocalAudioPersistenceTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
        audioStore = LectureLocalAudioStore(recordingsDirectory: recordingsDirectory)
        modelContainer = try ModelContainer(
            for: CachedLectureRecord.self, CachedFolderRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        cacheStore = SwiftDataLectureCacheStore(modelContainer: modelContainer, audioStore: audioStore)
    }

    // MARK: - Path persistence

    @Test func upsertStoresFileNameInsteadOfAbsoluteURL() throws {
        let fileURL = try makeAudioFile(named: "recording-\(UUID().uuidString).m4a")
        let lecture = makeLecture(audioURL: fileURL)

        try cacheStore.upsertLecture(lecture, for: userID)

        let record = try #require(try record(for: lecture.id))
        #expect(record.audioFileName == fileURL.lastPathComponent)
        let payloadLecture = try JSONDecoder().decode(Lecture.self, from: record.payload)
        #expect(payloadLecture.audioURL == nil)
        #expect(cacheStore.fetchLecture(id: lecture.id, for: userID)?.audioURL == fileURL)
    }

    @Test func fileNameSurvivesContainerMove() throws {
        let fileURL = try makeAudioFile(named: "recording-\(UUID().uuidString).m4a")
        let oldContainerURL = URL(filePath: "/var/mobile/Containers/Data/Application/\(UUID().uuidString)/Documents/Recordings")
            .appending(path: fileURL.lastPathComponent)
        let lecture = makeLecture(audioURL: oldContainerURL)

        try cacheStore.upsertLecture(lecture, for: userID)

        #expect(try record(for: lecture.id)?.audioFileName == fileURL.lastPathComponent)
        #expect(cacheStore.fetchLecture(id: lecture.id, for: userID)?.audioURL == fileURL)
    }

    @Test func legacyAbsolutePayloadResolvesInCurrentRecordingsDirectory() throws {
        let fileURL = try makeAudioFile(named: "recording-\(UUID().uuidString).m4a")
        let oldContainerURL = URL(filePath: "/old-container/Documents/Recordings").appending(path: fileURL.lastPathComponent)
        let lecture = makeLecture(audioURL: oldContainerURL)
        try insertLegacyRecord(for: lecture)

        #expect(cacheStore.fetchLecture(id: lecture.id, for: userID)?.audioURL == fileURL)

        // A Firestore snapshot that does not know the local file keeps the legacy link.
        var snapshotLecture = lecture
        snapshotLecture.audioURL = nil
        try cacheStore.replaceLectures([snapshotLecture], for: userID)

        #expect(try record(for: lecture.id)?.audioFileName == fileURL.lastPathComponent)
        #expect(cacheStore.fetchLecture(id: lecture.id, for: userID)?.audioURL == fileURL)
    }

    @Test func missingFileResolvesToNil() throws {
        let missingURL = recordingsDirectory.appending(path: "recording-missing.m4a")
        let lecture = makeLecture(audioURL: missingURL)

        try cacheStore.upsertLecture(lecture, for: userID)

        #expect(try record(for: lecture.id)?.audioFileName == "recording-missing.m4a")
        #expect(cacheStore.fetchLecture(id: lecture.id, for: userID)?.audioURL == nil)
    }

    // MARK: - Listener race

    /// The callable `upsertLecture` writes the Firestore document on the server,
    /// so the snapshot listener can rebuild the lecture (with no local audio URL,
    /// because it is not cached yet) before `saveLecture` upserts the cache.
    @Test func listenerSnapshotBeforeCacheUpsertDoesNotLoseLocalFile() throws {
        let fileURL = try makeAudioFile(named: "recording-\(UUID().uuidString).m4a")
        let lecture = makeLecture(audioURL: fileURL)
        var snapshotLecture = lecture
        snapshotLecture.audioURL = nil

        try cacheStore.replaceLectures([snapshotLecture], for: userID)
        try cacheStore.upsertLecture(lecture, for: userID)
        try cacheStore.replaceLectures([snapshotLecture], for: userID)

        #expect(cacheStore.fetchLecture(id: lecture.id, for: userID)?.audioURL == fileURL)
    }

    @Test func savingStaleCopyWithoutAudioURLKeepsLocalFile() throws {
        let fileURL = try makeAudioFile(named: "recording-\(UUID().uuidString).m4a")
        let lecture = makeLecture(audioURL: fileURL)
        try cacheStore.upsertLecture(lecture, for: userID)

        var staleCopy = lecture
        staleCopy.audioURL = nil
        staleCopy.title = "Renamed"
        try cacheStore.upsertLecture(staleCopy, for: userID)

        let fetchedLecture = cacheStore.fetchLecture(id: lecture.id, for: userID)
        #expect(fetchedLecture?.title == "Renamed")
        #expect(fetchedLecture?.audioURL == fileURL)
    }

    @Test func cachedLectureMapExposesResolvedURLForListener() throws {
        let fileURL = try makeAudioFile(named: "recording-\(UUID().uuidString).m4a")
        let lecture = makeLecture(audioURL: fileURL)
        try cacheStore.upsertLecture(lecture, for: userID)

        #expect(cacheStore.cachedLectureMap(for: userID)[lecture.id.uuidString]?.audioURL == fileURL)
    }

    // MARK: - Recovery

    @Test func recoversImportedFileNamedAfterLectureID() throws {
        let lecture = makeLecture(audioURL: nil)
        let fileURL = try makeAudioFile(named: "\(lecture.id.uuidString).mp3")
        try insertLegacyRecord(for: lecture)

        #expect(cacheStore.fetchLectures(for: userID).first?.audioURL == fileURL)

        try cacheStore.replaceLectures([lecture], for: userID)
        #expect(try record(for: lecture.id)?.audioFileName == fileURL.lastPathComponent)
    }

    @Test func doesNotGuessRecordingFilesOrOtherLectures() throws {
        let lecture = makeLecture(audioURL: nil)
        _ = try makeAudioFile(named: "recording-\(lecture.id.uuidString).m4a")
        _ = try makeAudioFile(named: "\(UUID().uuidString).mp3")
        try insertLegacyRecord(for: lecture)

        #expect(cacheStore.fetchLecture(id: lecture.id, for: userID)?.audioURL == nil)
    }

    @Test func doesNotRecoverAudioForNonAudioLectures() throws {
        let lecture = makeLecture(audioURL: nil, sourceType: .pdf)
        _ = try makeAudioFile(named: "\(lecture.id.uuidString).mp3")
        try insertLegacyRecord(for: lecture)

        #expect(cacheStore.fetchLecture(id: lecture.id, for: userID)?.audioURL == nil)
    }

    @Test func lectureIDNamedFilesIgnoresRecordings() throws {
        let lectureID = UUID()
        _ = try makeAudioFile(named: "\(lectureID.uuidString).m4a")
        _ = try makeAudioFile(named: "recording-\(UUID().uuidString).m4a")

        #expect(audioStore.lectureIDNamedFiles() == [lectureID.uuidString: "\(lectureID.uuidString).m4a"])
    }

    // MARK: - Helpers

    private func makeLecture(audioURL: URL?, sourceType: LectureSourceType = .audio) -> Lecture {
        Lecture(
            title: "Lecture",
            sourceType: sourceType,
            audioURL: audioURL,
            createdAt: .now,
            duration: .seconds(60),
            status: .ready,
            transcript: "",
            summaryShort: "",
            summaryLong: "",
            flashcards: [],
            quiz: []
        )
    }

    private func makeAudioFile(named fileName: String) throws -> URL {
        let url = recordingsDirectory.appending(path: fileName)
        try Data("audio".utf8).write(to: url)
        return url
    }

    /// Inserts a record the way builds before `audioFileName` stored it: the
    /// whole lecture, absolute `audioURL` included, in the payload.
    private func insertLegacyRecord(for lecture: Lecture) throws {
        let record = CachedLectureRecord(
            ownerUserID: userID,
            remoteID: lecture.id.uuidString,
            title: lecture.title,
            summaryShort: lecture.summaryShort,
            transcriptPreview: "",
            folderRemoteID: nil,
            createdAt: lecture.createdAt,
            payload: try JSONEncoder().encode(lecture)
        )
        modelContainer.mainContext.insert(record)
        try modelContainer.mainContext.save()
    }

    private func record(for lectureID: UUID) throws -> CachedLectureRecord? {
        let remoteID = lectureID.uuidString
        let descriptor = FetchDescriptor<CachedLectureRecord>(
            predicate: #Predicate { $0.remoteID == remoteID }
        )
        return try modelContainer.mainContext.fetch(descriptor).first
    }
}
