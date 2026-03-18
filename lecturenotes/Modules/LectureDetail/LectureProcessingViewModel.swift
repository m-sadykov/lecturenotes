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
    @ObservationIgnored private var observationTask: Task<Void, Never>?
    @ObservationIgnored private let onLectureUpdated: @MainActor (Lecture) -> Void

    init(
        lecture: Lecture,
        repository: LectureRepository,
        processingService: FirebaseLectureProcessingService,
        onLectureUpdated: @escaping @MainActor (Lecture) -> Void
    ) {
        self.lecture = lecture
        self.repository = repository
        self.processingService = processingService
        self.onLectureUpdated = onLectureUpdated
    }

    var shouldShowProcessing: Bool {
        lecture.status != .ready
    }

    func start() async {
        guard observationTask == nil else {
            return
        }

        do {
            let updates = try await processingService.lectureUpdates(for: lecture)
            observationTask = Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                do {
                    for try await updatedLecture in updates {
                        lecture = updatedLecture
                        onLectureUpdated(updatedLecture)
                        try? await repository.saveLecture(updatedLecture)
                    }
                } catch {
                    handleObservationError(error)
                }
            }
        } catch {
            handleObservationError(error)
        }
    }

    func stop() {
        observationTask?.cancel()
        observationTask = nil
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
        try? await repository.saveLecture(lecture)

        if observationTask == nil {
            await start()
        }

        do {
            let updatedLecture = try await processingService.startProcessing(for: lecture)
            lecture = updatedLecture
            onLectureUpdated(updatedLecture)
            try? await repository.saveLecture(updatedLecture)
        } catch {
            handleObservationError(error)
        }

        isRetrying = false
    }

    private func handleObservationError(_ error: Error) {
        observationTask = nil
        errorMessage = error.localizedDescription

        guard lecture.status != .ready else {
            return
        }

        lecture.status = .failed
        lecture.processingErrorMessage = error.localizedDescription
        onLectureUpdated(lecture)

        Task {
            try? await repository.saveLecture(lecture)
        }
    }
}
