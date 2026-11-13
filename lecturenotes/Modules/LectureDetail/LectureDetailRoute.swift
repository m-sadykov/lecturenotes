import Foundation

/// Screens pushed from the lecture detail screen.
enum LectureDetailRoute: Hashable, Identifiable {
    var id: Self { self }

    case transcript
    case keyPoints
}
