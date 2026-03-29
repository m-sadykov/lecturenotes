import Foundation
import Observation

@MainActor
@Observable
final class LectureProcessingViewModel {
    var lecture: Lecture
    var errorMessage: String?
    var isRetrying = false

    @ObservationIgnored private let repository: LectureRepository
    @ObservationIgnored private let processingService: FirebaseLectureProcessingService
    @ObservationIgnored private let analyticsService: AppAnalyticsService?
    @ObservationIgnored private let onLectureUpdated: @MainActor (Lecture) -> Void

    init(
        lecture: Lecture,
        repository: LectureRepository,
        processingService: FirebaseLectureProcessingService,
        analyticsService: AppAnalyticsService? = nil,
        onLectureUpdated: @escaping @MainActor (Lecture) -> Void
    ) {
        self.lecture = lecture
        self.repository = repository
        self.processingService = processingService
        self.analyticsService = analyticsService
        self.onLectureUpdated = onLectureUpdated
    }

    var shouldShowProcessing: Bool {
        lecture.status != .ready
    }

    func start() async {
        await repository.start()
    }

    func stop() {}

    func applyCachedLecture(_ updatedLecture: Lecture) {
        lecture = updatedLecture
        errorMessage = nil
    }

    func retryProcessing() async {
        guard !isRetrying else {
            return
        }

        isRetrying = true
        errorMessage = nil
        lecture.status = lecture.processingStartStatus
        lecture.processingErrorMessage = nil
        onLectureUpdated(lecture)

        do {
            let updatedLecture = try await processingService.startProcessing(for: lecture)
            lecture = updatedLecture
            onLectureUpdated(updatedLecture)
        } catch {
            handleObservationError(error)
        }

        isRetrying = false
    }

    private func handleObservationError(_ error: Error) {
        errorMessage = error.localizedDescription

        guard lecture.status != .ready else {
            return
        }

        lecture.status = .failed
        lecture.processingErrorMessage = error.localizedDescription
        onLectureUpdated(lecture)
        analyticsService?.track(
            .processingFailed(
                context: .init(lecture: lecture),
                plan: nil,
                stage: lecture.processingStartStatus.rawValue,
                reason: error.localizedDescription
            )
        )
    }
}
