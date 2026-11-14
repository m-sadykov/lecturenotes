import Foundation

/// What a lecture row shows about the lecture's processing state.
enum LectureRowStatus: Equatable {
    /// The lecture is ready or still a local draft; the row shows its usual metadata.
    case none
    /// Upload, transcription or generation is in progress.
    case processing(LectureStatus)
    /// Processing failed; the row offers a retry.
    case failed

    init(lecture: Lecture) {
        switch lecture.status {
        case .ready, .draft:
            self = .none
        case .uploading, .transcribing, .generating:
            self = .processing(lecture.status)
        case .failed:
            self = .failed
        }
    }
}
