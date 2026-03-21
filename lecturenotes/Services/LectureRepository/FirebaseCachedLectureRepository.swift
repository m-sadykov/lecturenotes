import FirebaseAuth
import FirebaseFirestore
import Foundation
import SwiftData

@MainActor
final class FirebaseCachedLectureRepository: LectureRepository {
    private let authService: FirebaseAuthService
    private let firestore: Firestore
    private let cacheStore: SwiftDataLectureCacheStore
    private let searchStore: SwiftDataLectureSearchStore
    private let syncService: FirebaseLectureSyncService
    private let commandService: FirebaseLectureCommandService
    private let notificationCenter: NotificationCenter
    private let notificationName: Notification.Name

    init(
        modelContainer: ModelContainer,
        authService: FirebaseAuthService,
        firestore: Firestore = Firestore.firestore(),
        notificationCenter: NotificationCenter = .default
    ) {
        let cacheStore = SwiftDataLectureCacheStore(modelContainer: modelContainer)
        let searchStore = SwiftDataLectureSearchStore(modelContainer: modelContainer)
        let notificationName = Notification.Name("lectureRepositoryDidChange.\(UUID().uuidString)")

        self.authService = authService
        self.firestore = firestore
        self.cacheStore = cacheStore
        self.searchStore = searchStore
        self.commandService = FirebaseLectureCommandService(authService: authService)
        self.notificationCenter = notificationCenter
        self.notificationName = notificationName
        self.syncService = FirebaseLectureSyncService(
            authService: authService,
            firestore: firestore,
            cacheStore: cacheStore,
            onCacheDidChange: { [notificationCenter, notificationName] in
                notificationCenter.post(name: notificationName, object: nil)
            }
        )
    }

    func start() async {
        await syncService.start()
    }

    func observeChanges() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task { [notificationCenter, notificationName] in
                for await _ in notificationCenter.notifications(
                    named: notificationName
                ) {
                    guard !Task.isCancelled else {
                        break
                    }

                    continuation.yield(())
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func fetchLectures() async -> [Lecture] {
        guard let userID = currentUserID else {
            return []
        }

        return cacheStore.fetchLectures(for: userID)
    }

    func searchLectures(matching query: String) async -> [Lecture] {
        guard let userID = currentUserID else {
            return []
        }

        let remoteIDs = await searchStore.searchLectureIDs(matching: query, for: userID)
        return cacheStore.fetchLectures(for: userID, remoteIDs: remoteIDs)
    }

    func fetchFolders() async -> [LectureFolder] {
        guard let userID = currentUserID else {
            return []
        }

        return cacheStore.fetchFolders(for: userID)
    }

    func fetchLecture(id: UUID) async -> Lecture? {
        guard let userID = currentUserID else {
            return nil
        }

        return cacheStore.fetchLecture(id: id, for: userID)
    }

    func saveLecture(_ lecture: Lecture) async throws {
        let user = try await authService.ensureSignedIn()
        try await commandService.upsertLecture(lecture)
        try cacheStore.upsertLecture(lecture, for: user.uid)
        postDidChange()
    }

    func saveFolders(_ folders: [LectureFolder]) async throws {
        let user = try await authService.ensureSignedIn()
        let collectionReference = foldersCollectionReference(userID: user.uid)
        let snapshot = try await getDocuments(in: collectionReference)
        let existingDocumentIDs = Set(snapshot.documents.map(\.documentID))
        let incomingDocumentIDs = Set(folders.map { $0.id.uuidString })
        let batch = firestore.batch()

        for folder in folders {
            let documentReference = collectionReference.document(folder.id.uuidString)
            let data = FirestoreFolderMapper.documentData(for: folder)
            batch.setData(data, forDocument: documentReference, merge: true)
        }

        for documentID in existingDocumentIDs.subtracting(incomingDocumentIDs) {
            batch.deleteDocument(collectionReference.document(documentID))
        }

        try await commit(batch)
        let cachedFolders = folders.map { (folder: $0, createdAt: Date.now) }
        try cacheStore.replaceFolders(cachedFolders, for: user.uid)
        postDidChange()
    }

    func deleteLecture(id: UUID) async throws {
        let user = try await authService.ensureSignedIn()
        try await commandService.deleteLecture(id)
        try cacheStore.deleteLecture(id: id, for: user.uid)
        postDidChange()
    }

    private var currentUserID: String? {
        authService.currentUserID
    }

    private func foldersCollectionReference(userID: String) -> CollectionReference {
        firestore
            .collection("users")
            .document(userID)
            .collection("folders")
    }

    private func getDocuments(in collectionReference: CollectionReference) async throws -> QuerySnapshot {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<QuerySnapshot, Error>) in
            collectionReference.getDocuments { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: CocoaError(.fileReadUnknown))
                }
            }
        }
    }

    private func commit(_ batch: WriteBatch) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            batch.commit { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func postDidChange() {
        notificationCenter.post(name: notificationName, object: nil)
    }
}
