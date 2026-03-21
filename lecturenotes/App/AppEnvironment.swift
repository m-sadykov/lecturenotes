import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppEnvironment {
    @ObservationIgnored var repository: LectureRepository
    @ObservationIgnored var modelContainer: ModelContainer?
    @ObservationIgnored var authService: FirebaseAuthService?
    @ObservationIgnored var userProfileService: FirebaseUserProfileService?
    @ObservationIgnored var processingService: FirebaseLectureProcessingService?

    init(
        repository: LectureRepository? = nil,
        modelContainer: ModelContainer? = nil,
        authService: FirebaseAuthService? = nil,
        userProfileService: FirebaseUserProfileService? = nil,
        processingService: FirebaseLectureProcessingService? = nil
    ) {
        let resolvedModelContainer = modelContainer ?? Self.makeModelContainer()
        self.modelContainer = resolvedModelContainer

        if let repository {
            self.repository = repository
        } else if let authService {
            self.repository = FirebaseCachedLectureRepository(
                modelContainer: resolvedModelContainer,
                authService: authService
            )
        } else {
            self.repository = LocalLectureRepository()
        }

        if let authService, let userProfileService {
            self.authService = authService
            self.userProfileService = userProfileService
            self.processingService = processingService ?? FirebaseLectureProcessingService(
                authService: authService,
                userProfileService: userProfileService
            )
            return
        }

        if let userProfileService {
            self.authService = authService
            self.userProfileService = userProfileService
            self.processingService = processingService
            return
        }

        if authService == nil, processingService == nil {
            self.authService = nil
            self.userProfileService = nil
            self.processingService = nil
            return
        }

        let resolvedAuthService = authService ?? FirebaseAuthService()
        let resolvedUserProfileService = FirebaseUserProfileService(authService: resolvedAuthService)
        self.authService = resolvedAuthService
        self.userProfileService = resolvedUserProfileService
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

    private static func makeModelContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: CachedLectureRecord.self, CachedFolderRecord.self)
        } catch {
            fatalError("Unable to create SwiftData cache container: \(error)")
        }
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
