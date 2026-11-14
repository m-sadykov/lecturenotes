import Foundation
import Testing
@testable import lecturenotes

@MainActor
struct HomeScreenTests {
    private func makeLecture(status: LectureStatus) -> Lecture {
        Lecture(
            title: "Lecture",
            createdAt: .now,
            duration: .seconds(60),
            status: status,
            transcript: "",
            summaryShort: "",
            summaryLong: "",
            flashcards: [],
            quiz: [],
            processingErrorMessage: status == .failed ? "Network error" : nil
        )
    }

    @Test(arguments: [LectureStatus.ready, .draft])
    func finishedLecturesShowNoStatus(status: LectureStatus) {
        #expect(LectureRowStatus(lecture: makeLecture(status: status)) == .none)
    }

    @Test(arguments: [LectureStatus.uploading, .transcribing, .generating])
    func inFlightLecturesShowProcessingStage(status: LectureStatus) {
        #expect(LectureRowStatus(lecture: makeLecture(status: status)) == .processing(status))
    }

    @Test func failedLectureShowsFailure() {
        #expect(LectureRowStatus(lecture: makeLecture(status: .failed)) == .failed)
    }

    @Test func retryWithoutProcessingServiceLeavesLectureFailed() {
        let viewModel = LecturesListViewModel(repository: SpyLectureRepository())
        let lecture = makeLecture(status: .failed)
        viewModel.lectures = [lecture]

        viewModel.retryProcessing(lecture.id)

        #expect(viewModel.lecture(withID: lecture.id)?.status == .failed)
        #expect(viewModel.lecture(withID: lecture.id)?.processingErrorMessage == "Network error")
    }

    @Test func dismissingSearchClearsQueryAndResults() {
        let viewModel = LecturesListViewModel(repository: SpyLectureRepository())
        viewModel.isSearchPresented = true
        viewModel.searchText = "photosynthesis"
        viewModel.searchResults = [makeLecture(status: .ready)]

        viewModel.dismissSearch()

        #expect(viewModel.isSearchPresented == false)
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.searchResults.isEmpty)
        #expect(viewModel.hasActiveSearchQuery == false)
    }
}
