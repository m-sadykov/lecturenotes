import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    var repository: LectureRepository

    init(repository: LectureRepository = MockLectureRepository()) {
        self.repository = repository
    }
}

@MainActor
@Observable
final class AppState {
    var needsOnboarding = true
}
