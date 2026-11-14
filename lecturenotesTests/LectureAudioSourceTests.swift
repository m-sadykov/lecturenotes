import Foundation
import Testing
@testable import lecturenotes

struct LectureAudioSourceTests {
    private let localURL = URL(filePath: "/tmp/Recordings/lecture.m4a")
    private let chunkFolder = "audio/user/F8DDD230-02A1-4F45-97C1-0B467E7BCB71"

    @Test func existingLocalFileWins() {
        let source = LectureAudioSource(
            localURL: localURL,
            remoteAudioPath: "\(chunkFolder)/chunk_1.m4a",
            remoteAudioChunkPaths: ["\(chunkFolder)/chunk_1.m4a", "\(chunkFolder)/chunk_2.m4a"],
            fileExists: { _ in true }
        )

        #expect(source == .local(localURL))
    }

    @Test func chunkedUploadUsesEveryChunk() {
        let source = LectureAudioSource(
            localURL: localURL,
            remoteAudioPath: "\(chunkFolder)/chunk_1.m4a",
            remoteAudioChunkPaths: [
                "\(chunkFolder)/chunk_1.m4a",
                "\(chunkFolder)/chunk_2.m4a",
                "\(chunkFolder)/chunk_3.m4a",
            ],
            fileExists: { _ in false }
        )

        #expect(source == .remote(paths: [
            "\(chunkFolder)/chunk_1.m4a",
            "\(chunkFolder)/chunk_2.m4a",
            "\(chunkFolder)/chunk_3.m4a",
        ]))
    }

    @Test func singleUploadUsesAudioPath() {
        let source = LectureAudioSource(
            localURL: nil,
            remoteAudioPath: "audio/user/lecture.mp3",
            remoteAudioChunkPaths: nil,
            fileExists: { _ in false }
        )

        #expect(source == .remote(paths: ["audio/user/lecture.mp3"]))
    }

    @Test func noAudioGivesNoSource() {
        let source = LectureAudioSource(
            localURL: nil,
            remoteAudioPath: nil,
            remoteAudioChunkPaths: [],
            fileExists: { _ in false }
        )

        #expect(source == nil)
    }

    @Test func chunksAreOrderedNumerically() {
        let paths = (1...11).map { "\(chunkFolder)/chunk_\($0).m4a" }

        #expect(LectureAudioSource.sortedByChunkNumber(paths.reversed()) == paths)
    }

    @Test func mapperReadsChunkPaths() {
        let lecture = FirestoreLectureMapper.lecture(
            from: [
                "audioPath": "\(chunkFolder)/chunk_1.m4a",
                "chunkPaths": ["\(chunkFolder)/chunk_1.m4a", "\(chunkFolder)/chunk_2.m4a"],
            ],
            fallbackDocumentID: "F8DDD230-02A1-4F45-97C1-0B467E7BCB71"
        )

        #expect(lecture?.remoteAudioChunkPaths == ["\(chunkFolder)/chunk_1.m4a", "\(chunkFolder)/chunk_2.m4a"])
    }

    @Test func mapperLeavesChunkPathsEmptyForSingleUploads() {
        let lecture = FirestoreLectureMapper.lecture(
            from: ["audioPath": "audio/user/lecture.m4a"],
            fallbackDocumentID: "F8DDD230-02A1-4F45-97C1-0B467E7BCB71"
        )

        #expect(lecture?.remoteAudioChunkPaths == nil)
    }

    @Test func cachedLecturesWithoutChunkPathsStillDecode() throws {
        var lecture = Lecture(
            title: "Old cache",
            createdAt: .now,
            duration: .seconds(60),
            status: .ready,
            transcript: "",
            summaryShort: "",
            summaryLong: "",
            flashcards: [],
            quiz: []
        )
        lecture.remoteAudioChunkPaths = nil
        var json = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(lecture)) as? [String: Any]
        )
        json.removeValue(forKey: "remoteAudioChunkPaths")
        let oldPayload = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(Lecture.self, from: oldPayload)

        #expect(decoded.remoteAudioChunkPaths == nil)
        #expect(decoded.title == "Old cache")
    }
}
