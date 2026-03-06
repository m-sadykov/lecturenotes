import Foundation
import Observation

@MainActor
@Observable
final class LecturesListViewModel {
    private let repository: LectureRepository

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
    }

    func addLecture(_ lectureID: Lecture.ID, toFolder folderID: LectureFolder.ID) {
        guard let lectureIndex = lectures.firstIndex(where: { $0.id == lectureID }) else {
            return
        }

        lectures[lectureIndex].folderID = folderID
        selectedFolderID = folderID
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
}
