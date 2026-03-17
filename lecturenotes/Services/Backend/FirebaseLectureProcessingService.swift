import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Foundation

@MainActor
final class FirebaseLectureProcessingService {
    private let authService: FirebaseAuthService
    private let firestore: Firestore
    private let storage: Storage
    private let audioChunker: LectureAudioChunker

    init(
        authService: FirebaseAuthService,
        firestore: Firestore = Firestore.firestore(),
        storage: Storage = Storage.storage(),
        audioChunker: LectureAudioChunker? = nil
    ) {
        self.authService = authService
        self.firestore = firestore
        self.storage = storage
        self.audioChunker = audioChunker ?? LectureAudioChunker()
    }

    func startProcessing(for lecture: Lecture) async throws -> Lecture {
        guard lecture.audioURL != nil else {
            throw FirebaseLectureProcessingError.missingAudioFile
        }

        let user = try await authService.ensureSignedIn()
        let uploadPlan = try await audioChunker.makeUploadPlan(for: lecture, userID: user.uid)
        let documentReference = lectureDocumentReference(userID: user.uid, lectureID: lecture.id)

        var processingLecture = lecture
        processingLecture.status = .uploading
        processingLecture.processingErrorMessage = nil

        try await setData(
            makeDocumentData(for: processingLecture, uploadPlan: uploadPlan),
            at: documentReference
        )

        do {
            try await uploadAudioFiles(for: uploadPlan)
            audioChunker.cleanup(plan: uploadPlan)
            return processingLecture
        } catch {
            audioChunker.cleanup(plan: uploadPlan)
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

    func deleteLecture(_ lecture: Lecture) async throws {
        let user = try await authService.ensureSignedIn()
        let documentReference = lectureDocumentReference(userID: user.uid, lectureID: lecture.id)
        let snapshot = try await getDocument(at: documentReference)
        let data = snapshot.data() ?? [:]
        let storedPaths = storagePaths(for: lecture, userID: user.uid, data: data)

        for path in storedPaths {
            try? await deleteStorageObject(at: storage.reference(withPath: path))
        }

        try await deleteDocument(at: documentReference)
    }

    private func lectureDocumentReference(userID: String, lectureID: UUID) -> DocumentReference {
        firestore
            .collection("users")
            .document(userID)
            .collection("lectures")
            .document(lectureID.uuidString)
    }

    private func makeDocumentData(for lecture: Lecture, uploadPlan: LectureAudioUploadPlan) -> [String: Any] {
        var data: [String: Any] = [
            "id": lecture.id.uuidString,
            "title": lecture.title,
            "createdAt": Timestamp(date: lecture.createdAt),
            "durationSec": lecture.duration.timeInterval,
            "status": lecture.status.rawValue,
            "transcript": lecture.transcript,
            "summaryShort": lecture.summaryShort,
            "summaryLong": lecture.summaryLong,
            "isChunked": uploadPlan.isChunked,
            "chunkCount": uploadPlan.items.count,
            "chunkPaths": uploadPlan.chunkPaths,
            "chunkTranscripts": [:] as [String: String],
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

        if let primaryAudioPath = uploadPlan.primaryAudioPath {
            data["audioPath"] = primaryAudioPath
        }

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

    private func getDocument(at documentReference: DocumentReference) async throws -> DocumentSnapshot {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DocumentSnapshot, Error>) in
            documentReference.getDocument { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: FirebaseLectureProcessingError.missingLectureDocument)
                }
            }
        }
    }

    private func deleteDocument(at documentReference: DocumentReference) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            documentReference.delete { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func uploadAudioFiles(for uploadPlan: LectureAudioUploadPlan) async throws {
        for item in uploadPlan.items {
            try await uploadAudioFile(
                at: item.fileURL,
                mimeType: item.mimeType,
                to: storage.reference(withPath: item.storagePath)
            )
        }
    }

    private func uploadAudioFile(at fileURL: URL, mimeType: String, to reference: StorageReference) async throws {
        let metadata = StorageMetadata()
        metadata.contentType = mimeType

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

    private func deleteStorageObject(at reference: StorageReference) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            reference.delete { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func storagePaths(for lecture: Lecture, userID: String, data: [String: Any]) -> [String] {
        if let chunkPaths = data["chunkPaths"] as? [String], !chunkPaths.isEmpty {
            return chunkPaths
        }

        if let audioPath = data["audioPath"] as? String, !audioPath.isEmpty {
            return [audioPath]
        }

        guard let audioURL = lecture.audioURL else {
            return []
        }

        let fileFormat = LectureAudioFormat(url: audioURL)
        return ["audio/\(userID)/\(lecture.id.uuidString).\(fileFormat.fileExtension)"]
    }

    private static func merge(lecture: Lecture, with data: [String: Any]) -> Lecture {
        var mergedLecture = lecture
        mergedLecture.title = stringValue(for: "title", in: data) ?? lecture.title
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
    case missingLectureDocument

    var errorDescription: String? {
        switch self {
        case .missingAudioFile:
            "Recording file is unavailable."
        case .missingLectureDocument:
            "Lecture document is unavailable."
        }
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        TimeInterval(components.seconds) + (TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000)
    }
}
