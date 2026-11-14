import Foundation
import Testing
@testable import lecturenotes

struct LectureYouTubeLinkTests {
    private func makeLecture(
        sourceType: LectureSourceType = .youtube,
        sourceURL: String? = nil,
        videoID: String? = nil
    ) -> Lecture {
        Lecture(
            title: "Lecture",
            sourceType: sourceType,
            sourceURL: sourceURL.flatMap(URL.init(string:)),
            youtubeVideoID: videoID,
            createdAt: .now,
            duration: .zero,
            status: .ready,
            transcript: "",
            summaryShort: "",
            summaryLong: "",
            flashcards: [],
            quiz: []
        )
    }

    @Test func videoIDBuildsWatchLink() {
        let lecture = makeLecture(sourceURL: "https://youtu.be/dQw4w9WgXcQ?t=42", videoID: "dQw4w9WgXcQ")

        #expect(lecture.youtubeWatchURL?.absoluteString == "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    }

    @Test(arguments: [
        "https://youtu.be/dQw4w9WgXcQ",
        "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        "https://m.youtube.com/watch?v=dQw4w9WgXcQ",
    ])
    func youtubeSourceURLIsUsedWithoutVideoID(link: String) {
        #expect(makeLecture(sourceURL: link).youtubeWatchURL?.absoluteString == link)
    }

    @Test func nonYouTubeSourceURLIsIgnored() {
        #expect(makeLecture(sourceURL: "https://evil.example/youtube.com").youtubeWatchURL == nil)
    }

    @Test func missingLinkGivesNoURL() {
        #expect(makeLecture(videoID: "  ").youtubeWatchURL == nil)
    }

    @Test func otherSourcesHaveNoYouTubeLink() {
        let lecture = makeLecture(sourceType: .audio, videoID: "dQw4w9WgXcQ")

        #expect(lecture.youtubeWatchURL == nil)
    }
}
