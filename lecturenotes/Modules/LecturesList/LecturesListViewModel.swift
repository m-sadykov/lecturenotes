import Foundation
import Observation

@MainActor
@Observable
final class LecturesListViewModel {
    private let repository: LectureRepository

    var lectures: [Lecture] = []
    var searchText = ""
    var selectedCourse = "All"
    var isLoading = false

    init(repository: LectureRepository) {
        self.repository = repository
    }

    var courses: [String] {
        let unique = Set(lectures.map(\.course)).sorted()
        return ["All"] + unique
    }

    var filteredLectures: [Lecture] {
        lectures.filter { lecture in
            let matchesCourse = selectedCourse == "All" || lecture.course == selectedCourse
            let matchesQuery =
                searchText.isEmpty ||
                lecture.title.localizedStandardContains(searchText) ||
                lecture.course.localizedStandardContains(searchText)
            return matchesCourse && matchesQuery
        }
    }

    func load() async {
        isLoading = true
        lectures = await repository.fetchLectures()
        isLoading = false
    }
}
