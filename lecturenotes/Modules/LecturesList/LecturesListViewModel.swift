import Foundation
import Observation

@MainActor
@Observable
final class LecturesListViewModel {
    enum SaveRecordingResult {
        case saved(Lecture)
        case rejected(message: String)
    }

    @ObservationIgnored private let repository: LectureRepository

    var lectures: [Lecture] = []
    var folders: [LectureFolder] = []
    var searchText = ""
    var selectedFolderID: LectureFolder.ID?
    var isLoading = false

    init(repository: LectureRepository) {
        self.repository = repository
    }

    var filteredLectures: [Lecture] {
        lectures.filter { lecture in
            let matchesFolder = selectedFolderID == nil || lecture.folderID == selectedFolderID
            let matchesQuery =
                searchText.isEmpty ||
                lecture.title.localizedStandardContains(searchText) ||
                lecture.course.localizedStandardContains(searchText)
            return matchesFolder && matchesQuery
        }
    }

    func lecture(withID lectureID: Lecture.ID) -> Lecture? {
        lectures.first(where: { $0.id == lectureID })
    }

    func createFolder(named name: String) {
        let uniqueName = makeUniqueFolderName(from: name)
        let folder = LectureFolder(name: uniqueName)
        folders.append(folder)
        persistFolders()
    }

    func addLecture(_ lectureID: Lecture.ID, toFolder folderID: LectureFolder.ID) {
        guard let lectureIndex = lectures.firstIndex(where: { $0.id == lectureID }) else {
            return
        }

        lectures[lectureIndex].folderID = folderID
        selectedFolderID = folderID
        persistLecture(at: lectureIndex)
    }

    func removeLectureFromFolder(_ lectureID: Lecture.ID) -> String? {
        guard let lectureIndex = lectures.firstIndex(where: { $0.id == lectureID }) else {
            return nil
        }

        let removedFolderID = lectures[lectureIndex].folderID
        let folderName = folders.first(where: { $0.id == removedFolderID })?.name
        lectures[lectureIndex].folderID = nil

        if selectedFolderID == removedFolderID {
            selectedFolderID = nil
        }

        persistLecture(at: lectureIndex)
        return folderName
    }

    func deleteFolder(_ folderID: LectureFolder.ID) {
        folders.removeAll { $0.id == folderID }

        for lectureIndex in lectures.indices where lectures[lectureIndex].folderID == folderID {
            lectures[lectureIndex].folderID = nil
        }

        if selectedFolderID == folderID {
            selectedFolderID = nil
        }

        persistFolders()
        persistAllLectures()
    }

    func saveRecording(_ recording: RecorderViewModel.RecordingDraft) async -> SaveRecordingResult {
        let minimumDuration = Duration.seconds(3)
        guard recording.duration >= minimumDuration else {
            return .rejected(message: "Recording must be at least 3 seconds long.")
        }

        let lecture = Lecture(
            title: "New Recording",
            course: recording.courseName,
            audioURL: recording.audioURL,
            createdAt: recording.createdAt,
            duration: recording.duration,
            status: .ready,
            transcript: "",
            summaryShort: "",
            summaryLong: "",
            flashcards: [],
            quiz: []
        )

        lectures.insert(lecture, at: 0)
        do {
            try await repository.saveLecture(lecture)
            return .saved(lecture)
        } catch {
            lectures.removeAll { $0.id == lecture.id }
            return .rejected(message: "Unable to save recording right now.")
        }
    }

    func deleteLecture(_ lectureID: Lecture.ID) {
        guard lecture(withID: lectureID) != nil else {
            return
        }

        lectures.removeAll { $0.id == lectureID }

        Task {
            try? await repository.deleteLecture(id: lectureID)
        }
    }

    func load() async {
        isLoading = true
        folders = await repository.fetchFolders()
        lectures = await repository.fetchLectures()
        isLoading = false
    }

    private func makeUniqueFolderName(from name: String) -> String {
        let existingNames = Set(folders.map(\.name))
        guard existingNames.contains(name) else {
            return name
        }

        var index = 2
        while existingNames.contains("\(name) \(index)") {
            index += 1
        }
        return "\(name) \(index)"
    }

    private func persistFolders() {
        let folders = self.folders
        Task {
            try? await repository.saveFolders(folders)
        }
    }

    private func persistLecture(at index: Int) {
        guard lectures.indices.contains(index) else {
            return
        }

        let lecture = lectures[index]
        Task {
            try? await repository.saveLecture(lecture)
        }
    }

    private func persistAllLectures() {
        let lectures = self.lectures
        Task {
            for lecture in lectures {
                try? await repository.saveLecture(lecture)
            }
        }
    }
}
