import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    @ObservationIgnored var repository: LectureRepository
    @ObservationIgnored var authService: FirebaseAuthService
    @ObservationIgnored var userProfileService: FirebaseUserProfileService
    @ObservationIgnored var processingService: FirebaseLectureProcessingService?

    init(
        repository: LectureRepository? = nil,
        authService: FirebaseAuthService? = nil,
        userProfileService: FirebaseUserProfileService? = nil,
        processingService: FirebaseLectureProcessingService? = nil
    ) {
        let resolvedAuthService = authService ?? FirebaseAuthService()
        let resolvedUserProfileService = userProfileService ?? FirebaseUserProfileService(authService: resolvedAuthService)
        self.authService = resolvedAuthService
        self.userProfileService = resolvedUserProfileService
        self.repository = repository ?? LocalLectureRepository()
        self.processingService = processingService ?? FirebaseLectureProcessingService(
            authService: resolvedAuthService,
            userProfileService: resolvedUserProfileService
        )
    }

    static func preview(repository: LectureRepository? = nil) -> AppEnvironment {
        AppEnvironment(
            repository: repository ?? MockLectureRepository(),
            processingService: nil
        )
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
