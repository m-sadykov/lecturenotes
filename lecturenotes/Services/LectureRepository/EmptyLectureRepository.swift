import Foundation

struct EmptyLectureRepository: LectureRepository {
    func fetchLectures() async -> [Lecture] {
        []
    }

    func fetchFolders() async -> [LectureFolder] {
        []
    }

    func fetchLecture(id: UUID) async -> Lecture? {
        nil
    }

    func saveLecture(_ lecture: Lecture) async throws {}

    func saveFolders(_ folders: [LectureFolder]) async throws {}

    func deleteLecture(id: UUID) async throws {}
}
