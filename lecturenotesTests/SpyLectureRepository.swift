import Foundation
@testable import lecturenotes

/// In-memory repository that records saved lectures so tests can assert on side effects.
final class SpyLectureRepository: LectureRepository {
    private(set) var savedLectures: [Lecture] = []

    func fetchLectures() async -> [Lecture] {
        savedLectures
    }

    func fetchFolders() async -> [LectureFolder] {
        []
    }

    func fetchLecture(id: UUID) async -> Lecture? {
        savedLectures.first { $0.id == id }
    }

    func saveLecture(_ lecture: Lecture) async throws {
        savedLectures.append(lecture)
    }

    func saveFolders(_ folders: [LectureFolder]) async throws {}

    func deleteLecture(id: UUID) async throws {
        savedLectures.removeAll { $0.id == id }
    }
}
