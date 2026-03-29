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
    @ObservationIgnored var analyticsService: AppAnalyticsService
    @ObservationIgnored var crashReportingService: CrashReportingService

    init(
        repository: LectureRepository? = nil,
        modelContainer: ModelContainer? = nil,
        authService: FirebaseAuthService? = nil,
        userProfileService: FirebaseUserProfileService? = nil,
        processingService: FirebaseLectureProcessingService? = nil,
        analyticsService: AppAnalyticsService? = nil,
        crashReportingService: CrashReportingService? = nil
    ) {
        let resolvedModelContainer = modelContainer ?? Self.makeModelContainer()
        let resolvedAnalyticsService = analyticsService ?? AppAnalyticsService()
        let resolvedCrashReportingService = crashReportingService ?? CrashReportingService()
        self.modelContainer = resolvedModelContainer
        self.analyticsService = resolvedAnalyticsService
        self.crashReportingService = resolvedCrashReportingService

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
                userProfileService: userProfileService,
                crashReportingService: resolvedCrashReportingService
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
            userProfileService: resolvedUserProfileService,
            crashReportingService: resolvedCrashReportingService
        )
    }

    static func preview(repository: LectureRepository? = nil) -> AppEnvironment {
        AppEnvironment(
            repository: repository ?? MockLectureRepository(),
            processingService: nil,
            analyticsService: AppAnalyticsService(isEnabled: false),
            crashReportingService: CrashReportingService(isEnabled: false)
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
    var needsOnboarding: Bool {
        didSet {
            userDefaults.set(needsOnboarding, forKey: Self.needsOnboardingKey)
        }
    }

    var selectedLanguage: AppLanguage {
        didSet {
            userDefaults.set(selectedLanguage.rawValue, forKey: Self.selectedLanguageKey)
            userDefaults.set([selectedLanguage.rawValue], forKey: Self.appleLanguagesKey)
            Bundle.setAppLanguage(selectedLanguage)
            AppInterfaceLayoutDirection.apply(for: selectedLanguage)
        }
    }

    @ObservationIgnored private let userDefaults: UserDefaults

    private static let needsOnboardingKey = "appState.needsOnboarding"
    private static let selectedLanguageKey = "appState.selectedLanguage"
    private static let appleLanguagesKey = "AppleLanguages"

    var locale: Locale {
        selectedLanguage.locale
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.needsOnboarding = userDefaults.object(forKey: Self.needsOnboardingKey) as? Bool ?? true
        self.selectedLanguage = AppLanguage(rawValue: userDefaults.string(forKey: Self.selectedLanguageKey) ?? "") ?? .english
        userDefaults.set([selectedLanguage.rawValue], forKey: Self.appleLanguagesKey)
        Bundle.setAppLanguage(selectedLanguage)
        AppInterfaceLayoutDirection.apply(for: selectedLanguage)
    }

    static func preview(
        needsOnboarding: Bool = false,
        selectedLanguage: AppLanguage = .english
    ) -> AppState {
        let state = AppState()
        state.needsOnboarding = needsOnboarding
        state.selectedLanguage = selectedLanguage
        return state
    }
}
