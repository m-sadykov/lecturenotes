import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    @ObservationIgnored var repository: LectureRepository

    init(repository: LectureRepository? = nil) {
        self.repository = repository ?? LocalLectureRepository()
    }

    static func preview(repository: LectureRepository? = nil) -> AppEnvironment {
        AppEnvironment(repository: repository ?? MockLectureRepository())
    }
}

@MainActor
@Observable
final class AppState {
    var needsOnboarding = true

    static func preview(needsOnboarding: Bool = false) -> AppState {
        let state = AppState()
        state.needsOnboarding = needsOnboarding
        return state
    }
}
