import Testing
@testable import lecturenotes

@MainActor
struct YouTubeImportAccessTests {
    private let validURL = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"

    @Test func freemiumPlanCannotImportFromYouTube() {
        #expect(AppUserPlan.freemium.canImportFromYouTube == false)
    }

    @Test(arguments: [AppUserPlan.premium, .pro])
    func paidPlansCanImportFromYouTube(plan: AppUserPlan) {
        #expect(plan.canImportFromYouTube)
    }

    @Test func freemiumSubmitShowsPaywallWithoutImporting() async {
        let repository = SpyLectureRepository()
        let viewModel = LecturesListViewModel(repository: repository)
        viewModel.isYouTubeImportSheetPresented = true

        let error = await viewModel.submitYouTubeImport(validURL, plan: .freemium)

        #expect(error == nil)
        #expect(repository.savedLectures.isEmpty)
        #expect(viewModel.lectures.isEmpty)
        #expect(viewModel.pendingYouTubeImportLecture == nil)
        #expect(viewModel.isYouTubeImportSheetPresented == false)
        #expect(viewModel.consumeYouTubeImportPaywallRequest())
        #expect(viewModel.consumeYouTubeImportPaywallRequest() == false)
    }

    @Test(arguments: [AppUserPlan.premium, .pro])
    func paidSubmitImportsWithoutPaywall(plan: AppUserPlan) async {
        let repository = SpyLectureRepository()
        let viewModel = LecturesListViewModel(repository: repository)
        viewModel.isYouTubeImportSheetPresented = true

        let error = await viewModel.submitYouTubeImport(validURL, plan: plan)

        #expect(error == nil)
        #expect(repository.savedLectures.count == 1)
        #expect(repository.savedLectures.first?.sourceType == .youtube)
        #expect(repository.savedLectures.first?.youtubeVideoID == "dQw4w9WgXcQ")
        #expect(viewModel.pendingYouTubeImportLecture != nil)
        #expect(viewModel.isYouTubeImportSheetPresented == false)
        #expect(viewModel.consumeYouTubeImportPaywallRequest() == false)
    }

    @Test func paidSubmitWithInvalidLinkStillReportsError() async {
        let repository = SpyLectureRepository()
        let viewModel = LecturesListViewModel(repository: repository)

        let error = await viewModel.submitYouTubeImport("not a link", plan: .pro)

        #expect(error == .invalidLink)
        #expect(repository.savedLectures.isEmpty)
        #expect(viewModel.consumeYouTubeImportPaywallRequest() == false)
    }
}
