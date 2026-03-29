import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Foundation

@MainActor
final class FirebaseLectureProcessingService {
    private let authService: FirebaseAuthService
    private let userProfileService: FirebaseUserProfileService
    private let firestore: Firestore
    private let storage: Storage
    private let audioChunker: LectureAudioChunker
    private let commandService: FirebaseLectureCommandService

    init(
        authService: FirebaseAuthService,
        userProfileService: FirebaseUserProfileService,
        firestore: Firestore? = nil,
        storage: Storage? = nil,
        audioChunker: LectureAudioChunker? = nil
    ) {
        self.authService = authService
        self.userProfileService = userProfileService
        self.firestore = firestore ?? Firestore.firestore()
        self.storage = storage ?? Storage.storage()
        self.audioChunker = audioChunker ?? LectureAudioChunker()
        self.commandService = FirebaseLectureCommandService(authService: authService)
    }

    func startProcessing(for lecture: Lecture) async throws -> Lecture {
        var processingLecture = lecture
        processingLecture.processingErrorMessage = nil

        do {
            let userProfile = try await userProfileService.ensureCurrentUserProfile()
            guard userProfile.canStartProcessing else {
                throw FirebaseLectureProcessingError.processingLimitExceeded(
                    remainingCount: userProfile.processingQuota.remainingCount
                )
            }

            switch lecture.sourceType {
            case .audio:
                guard lecture.duration <= userProfile.audioImportLimitDuration else {
                    throw FirebaseLectureProcessingError.audioLimitExceeded(
                        limit: userProfile.audioImportLimitDuration
                    )
                }

                guard lecture.audioURL != nil else {
                    throw FirebaseLectureProcessingError.missingAudioFile
                }

                let user = try await authService.ensureSignedIn()
                let uploadPlan = try await audioChunker.makeUploadPlan(for: lecture, userID: user.uid)
                processingLecture.status = .uploading

                try await commandService.startProcessing(
                    lectureID: lecture.id,
                    uploadPlan: uploadPlan
                )

                do {
                    try await uploadAudioFiles(for: uploadPlan)
                    audioChunker.cleanup(plan: uploadPlan)
                    return processingLecture
                } catch {
                    audioChunker.cleanup(plan: uploadPlan)
                    throw error
                }
            case .text, .pdf:
                let trimmedTranscript = lecture.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedTranscript.isEmpty else {
                    throw FirebaseLectureProcessingError.missingTranscript
                }

                processingLecture.status = .generating
                processingLecture.transcript = trimmedTranscript
                try await commandService.startProcessing(lectureID: lecture.id)
                return processingLecture
            case .youtube:
                guard let sourceURL = lecture.sourceURL else {
                    throw FirebaseLectureProcessingError.missingSourceURL
                }

                processingLecture.status = lecture.processingStartStatus
                processingLecture.sourceURL = sourceURL
                processingLecture.transcript = lecture.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                try await commandService.startProcessing(lectureID: lecture.id)
                return processingLecture
            }
        } catch {
            await commandService.markLectureFailed(lecture.id, message: error.localizedDescription)
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

                let updatedLecture = FirestoreLectureMapper.lecture(
                    from: data,
                    fallbackDocumentID: snapshot.documentID,
                    preservedLocalAudioURL: lecture.audioURL
                ) ?? lecture
                continuation.yield(updatedLecture)
            }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    func deleteLecture(_ lecture: Lecture) async throws {
        try await commandService.deleteLecture(lecture.id)
    }

    func updateLectureTitle(_ title: String, for lecture: Lecture) async throws -> Lecture {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        var updatedLecture = lecture
        updatedLecture.title = trimmedTitle
        try await commandService.upsertLecture(updatedLecture)
        return updatedLecture
    }

    private func lectureDocumentReference(userID: String, lectureID: UUID) -> DocumentReference {
        firestore
            .collection("users")
            .document(userID)
            .collection("lectures")
            .document(lectureID.uuidString)
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

}

enum FirebaseLectureProcessingError: LocalizedError {
    case missingAudioFile
    case missingTranscript
    case missingSourceURL
    case missingLectureDocument
    case processingLimitExceeded(remainingCount: Int)
    case audioLimitExceeded(limit: Duration)

    var errorDescription: String? {
        switch self {
        case .missingAudioFile:
            return String(localized: "Recording file is unavailable.")
        case .missingTranscript:
            return String(localized: "Imported content is empty.")
        case .missingSourceURL:
            return String(localized: "Source URL is unavailable.")
        case .missingLectureDocument:
            return String(localized: "Lecture document is unavailable.")
        case .processingLimitExceeded(let remainingCount):
            return String(localized: "Not enough processing attempts left. Remaining: \(max(remainingCount, 0)).")
        case .audioLimitExceeded(let limit):
            return String(localized: "Audio is too long for your current plan. Limit: \(LectureFormatters.durationText(limit)).")
        }
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        TimeInterval(components.seconds) + (TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000)
    }
}
