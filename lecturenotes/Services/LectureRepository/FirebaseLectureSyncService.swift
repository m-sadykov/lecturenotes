import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class FirebaseLectureSyncService {
    private let authService: FirebaseAuthService
    private let firestore: Firestore
    private let cacheStore: SwiftDataLectureCacheStore
    private let onCacheDidChange: @MainActor () -> Void

    private var activeUserID: String?
    private var lecturesListener: ListenerRegistration?
    private var foldersListener: ListenerRegistration?

    init(
        authService: FirebaseAuthService,
        firestore: Firestore = Firestore.firestore(),
        cacheStore: SwiftDataLectureCacheStore,
        onCacheDidChange: @escaping @MainActor () -> Void
    ) {
        self.authService = authService
        self.firestore = firestore
        self.cacheStore = cacheStore
        self.onCacheDidChange = onCacheDidChange
    }

    func start() async {
        do {
            let user = try await authService.ensureSignedIn()
            let userID = user.uid

            guard activeUserID != userID || lecturesListener == nil || foldersListener == nil else {
                return
            }

            stop()
            activeUserID = userID
            try? cacheStore.pruneData(excluding: userID)
            startLecturesListener(for: userID)
            startFoldersListener(for: userID)
        } catch {
            stop()
        }
    }

    func stop() {
        lecturesListener?.remove()
        foldersListener?.remove()
        lecturesListener = nil
        foldersListener = nil
        activeUserID = nil
    }

    private func startLecturesListener(for userID: String) {
        lecturesListener = firestore
            .collection("users")
            .document(userID)
            .collection("lectures")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot, error == nil else {
                    return
                }

                Task { @MainActor [weak self] in
                    guard let self else {
                        return
                    }

                    let cachedLectures = cacheStore.cachedLectureMap(for: userID)
                    let lectures = snapshot.documents.compactMap { document in
                        FirestoreLectureMapper.lecture(
                            from: document.data(),
                            fallbackDocumentID: document.documentID,
                            preservedLocalAudioURL: cachedLectures[document.documentID]?.audioURL
                        )
                    }

                    do {
                        try cacheStore.replaceLectures(lectures, for: userID)
                        onCacheDidChange()
                    } catch {
                        return
                    }
                }
            }
    }

    private func startFoldersListener(for userID: String) {
        foldersListener = firestore
            .collection("users")
            .document(userID)
            .collection("folders")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot, error == nil else {
                    return
                }

                Task { @MainActor [weak self] in
                    guard let self else {
                        return
                    }

                    let folders: [(folder: LectureFolder, createdAt: Date)] = snapshot.documents.compactMap { document in
                        guard let folder = FirestoreFolderMapper.folder(
                            from: document.data(),
                            fallbackDocumentID: document.documentID
                        ) else {
                            return nil
                        }

                        return (folder: folder, createdAt: FirestoreFolderMapper.createdAt(from: document.data()))
                    }

                    do {
                        try cacheStore.replaceFolders(folders, for: userID)
                        onCacheDidChange()
                    } catch {
                        return
                    }
                }
            }
    }
}
