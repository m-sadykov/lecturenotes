import Foundation

/// Looks up audio files named after a lecture ID, listing the recordings
/// directory at most once per cache operation.
nonisolated struct LectureAudioFileResolver {
    let audioStore: LectureLocalAudioStore
    private var lectureIDNamedFiles: [String: String]?

    init(audioStore: LectureLocalAudioStore) {
        self.audioStore = audioStore
    }

    mutating func lectureIDNamedFileName(for lecture: Lecture) -> String? {
        guard lecture.sourceType == .audio else {
            return nil
        }

        if lectureIDNamedFiles == nil {
            lectureIDNamedFiles = audioStore.lectureIDNamedFiles()
        }

        return lectureIDNamedFiles?[lecture.id.uuidString]
    }
}
