import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Foundation

@MainActor
final class FirebaseLectureProcessingService {
    private let authService: FirebaseAuthService
    private let firestore: Firestore
    private let storage: Storage

    init(
        authService: FirebaseAuthService,
        firestore: Firestore = Firestore.firestore(),
        storage: Storage = Storage.storage()
    ) {
        self.authService = authService
        self.firestore = firestore
        self.storage = storage
    }

    func startProcessing(for lecture: Lecture) async throws -> Lecture {
        guard let audioURL = lecture.audioURL else {
            throw FirebaseLectureProcessingError.missingAudioFile
        }

        let user = try await authService.ensureSignedIn()
        let storagePath = "audio/\(user.uid)/\(lecture.id.uuidString).m4a"
        let documentReference = lectureDocumentReference(userID: user.uid, lectureID: lecture.id)

        var processingLecture = lecture
        processingLecture.status = .uploading
        processingLecture.processingErrorMessage = nil

        try await setData(
            makeDocumentData(for: processingLecture, audioPath: storagePath),
            at: documentReference
        )

        do {
            try await uploadAudioFile(at: audioURL, to: storage.reference(withPath: storagePath))
            return processingLecture
        } catch {
            try? await setData(
                [
                    "status": LectureStatus.failed.rawValue,
                    "errorMessage": error.localizedDescription,
                    "updatedAt": FieldValue.serverTimestamp()
                ],
                at: documentReference,
                merge: true
            )
            throw error
        }
    }

    func lectureUpdates(for lecture: Lecture) async throws -> AsyncThrowingStream<Lecture, Error> {
        let user = try await authService.ensureSignedIn()
        let documentReference = lectureDocumentReference(userID: user.uid, lectureID: lecture.id)

        return AsyncThrowingStream { continuation in
            let listener = documentReference.addSnapshotListener { snapshot, error in
                if let error {
                    continuation.finish(throwing: error)
                    return
                }

                guard let snapshot, snapshot.exists, let data = snapshot.data() else {
                    return
                }

                let updatedLecture = Self.merge(lecture: lecture, with: data)
                continuation.yield(updatedLecture)
            }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    private func lectureDocumentReference(userID: String, lectureID: UUID) -> DocumentReference {
        firestore
            .collection("users")
            .document(userID)
            .collection("lectures")
            .document(lectureID.uuidString)
    }

    private func makeDocumentData(for lecture: Lecture, audioPath: String) -> [String: Any] {
        var data: [String: Any] = [
            "id": lecture.id.uuidString,
            "title": lecture.title,
            "course": lecture.course,
            "createdAt": Timestamp(date: lecture.createdAt),
            "durationSec": lecture.duration.timeInterval,
            "status": lecture.status.rawValue,
            "audioPath": audioPath,
            "transcript": lecture.transcript,
            "summaryShort": lecture.summaryShort,
            "summaryLong": lecture.summaryLong,
            "flashcards": lecture.flashcards.map {
                [
                    "id": $0.id.uuidString,
                    "question": $0.question,
                    "answer": $0.answer
                ]
            },
            "quiz": lecture.quiz.map {
                [
                    "id": $0.id.uuidString,
                    "question": $0.question,
                    "options": $0.options,
                    "correctIndex": $0.correctIndex
                ]
            },
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let processingErrorMessage = lecture.processingErrorMessage {
            data["errorMessage"] = processingErrorMessage
        }

        return data
    }

    private func setData(
        _ data: [String: Any],
        at documentReference: DocumentReference,
        merge: Bool = false
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            documentReference.setData(data, merge: merge) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func uploadAudioFile(at fileURL: URL, to reference: StorageReference) async throws {
        let metadata = StorageMetadata()
        metadata.contentType = "audio/m4a"

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            reference.putFile(from: fileURL, metadata: metadata) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private static func merge(lecture: Lecture, with data: [String: Any]) -> Lecture {
        var mergedLecture = lecture
        mergedLecture.title = stringValue(for: "title", in: data) ?? lecture.title
        mergedLecture.course = stringValue(for: "course", in: data) ?? lecture.course
        mergedLecture.createdAt = dateValue(for: "createdAt", in: data) ?? lecture.createdAt
        mergedLecture.duration = .seconds(doubleValue(for: "durationSec", in: data) ?? lecture.duration.timeInterval)
        mergedLecture.status = LectureStatus(rawValue: stringValue(for: "status", in: data) ?? "") ?? lecture.status
        mergedLecture.transcript = stringValue(for: "transcript", in: data) ?? ""
        mergedLecture.summaryShort = stringValue(for: "summaryShort", in: data) ?? ""
        mergedLecture.summaryLong = stringValue(for: "summaryLong", in: data) ?? ""
        mergedLecture.flashcards = flashcardsValue(for: "flashcards", in: data)
        mergedLecture.quiz = quizValue(for: "quiz", in: data)
        mergedLecture.processingErrorMessage = stringValue(for: "errorMessage", in: data)
        return mergedLecture
    }

    private static func stringValue(for key: String, in data: [String: Any]) -> String? {
        data[key] as? String
    }

    private static func doubleValue(for key: String, in data: [String: Any]) -> Double? {
        if let value = data[key] as? Double {
            return value
        }

        if let value = data[key] as? Int {
            return Double(value)
        }

        return nil
    }

    private static func dateValue(for key: String, in data: [String: Any]) -> Date? {
        if let timestamp = data[key] as? Timestamp {
            return timestamp.dateValue()
        }

        return data[key] as? Date
    }

    private static func flashcardsValue(for key: String, in data: [String: Any]) -> [Flashcard] {
        let values = data[key] as? [[String: Any]] ?? []

        return values.map { item in
            Flashcard(
                id: UUID(uuidString: item["id"] as? String ?? "") ?? UUID(),
                question: item["question"] as? String ?? "",
                answer: item["answer"] as? String ?? ""
            )
        }
    }

    private static func quizValue(for key: String, in data: [String: Any]) -> [QuizQuestion] {
        let values = data[key] as? [[String: Any]] ?? []

        return values.map { item in
            QuizQuestion(
                id: UUID(uuidString: item["id"] as? String ?? "") ?? UUID(),
                question: item["question"] as? String ?? "",
                options: item["options"] as? [String] ?? [],
                correctIndex: item["correctIndex"] as? Int ?? 0
            )
        }
    }
}

enum FirebaseLectureProcessingError: LocalizedError {
    case missingAudioFile

    var errorDescription: String? {
        switch self {
        case .missingAudioFile:
            "Recording file is unavailable."
        }
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        TimeInterval(components.seconds) + (TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000)
    }
}
