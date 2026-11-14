import FirebaseFunctions
import Foundation

@MainActor
final class FirebaseLectureCommandService {
    private let authService: FirebaseAuthService
    private let functions: Functions

    init(
        authService: FirebaseAuthService,
        functions: Functions = Functions.functions()
    ) {
        self.authService = authService
        self.functions = functions
    }

    func upsertLecture(_ lecture: Lecture) async throws {
        _ = try await authService.ensureSignedIn()

        let payload: [String: Any] = [
            "lectureId": lecture.id.uuidString,
            "title": lecture.title,
            "sourceType": lecture.sourceType.rawValue,
            "durationSec": lecture.duration.timeInterval,
            "pdfPageCount": lecture.pdfPageCount ?? NSNull(),
            "transcript": lecture.transcript,
            "sourceURL": lecture.sourceURL?.absoluteString ?? NSNull(),
            "youtubeVideoID": lecture.youtubeVideoID ?? NSNull(),
            "folderID": lecture.folderID?.uuidString ?? NSNull(),
        ]

        try await call(
            "upsertLecture",
            data: payload
        )
    }

    func startProcessing(
        lectureID: UUID,
        uploadPlan: LectureAudioUploadPlan? = nil
    ) async throws {
        _ = try await authService.ensureSignedIn()

        var payload: [String: Any] = [
            "lectureId": lectureID.uuidString
        ]

        if let uploadPlan {
            let audioPayload: [String: Any] = [
                "isChunked": uploadPlan.isChunked,
                "chunkPaths": uploadPlan.chunkPaths,
                "primaryAudioPath": uploadPlan.primaryAudioPath ?? NSNull(),
            ]
            payload["audioUpload"] = audioPayload
        }

        try await call("startLectureProcessing", data: payload)
    }

    func markLectureFailed(_ lectureID: UUID, message: String) async {
        do {
            _ = try await authService.ensureSignedIn()
            try await call(
                "markLectureFailed",
                data: [
                    "lectureId": lectureID.uuidString,
                    "message": message
                ]
            )
        } catch {
            return
        }
    }

    func deleteLecture(_ lectureID: UUID) async throws {
        _ = try await authService.ensureSignedIn()
        try await call(
            "deleteLectureCascade",
            data: [
                "lectureId": lectureID.uuidString
            ]
        )
    }

    /// Asks the backend for a new set of flashcards or quiz questions for a ready lecture.
    /// The function saves the set to the lecture document and returns it.
    func regenerateStudyItems(
        lectureID: UUID,
        kind: StudyItemsKind
    ) async throws -> RegeneratedStudyItems {
        _ = try await authService.ensureSignedIn()

        let data: [String: Any] = [
            "lectureId": lectureID.uuidString,
            "kind": kind.rawValue,
        ]

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<RegeneratedStudyItems, Error>) in
            functions.httpsCallable("regenerateStudyItems").call(data) { result, error in
                if let error {
                    continuation.resume(throwing: StudyItemsRegenerationError(error: error))
                    return
                }

                let items = (result?.data as? [String: Any])?["items"]
                let regenerated: RegeneratedStudyItems = switch kind {
                case .flashcards:
                    .flashcards(FirestoreLectureMapper.flashcards(from: items))
                case .quiz:
                    .quiz(FirestoreLectureMapper.quiz(from: items))
                }

                if regenerated.isEmpty {
                    continuation.resume(throwing: StudyItemsRegenerationError.failed)
                } else {
                    continuation.resume(returning: regenerated)
                }
            }
        }
    }

    private func call(_ name: String, data: Any) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            functions.httpsCallable(name).call(data) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        TimeInterval(components.seconds) + (TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000)
    }
}
