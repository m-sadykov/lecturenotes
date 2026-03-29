import Foundation

struct LectureAnalyticsContext {
    let lectureID: UUID
    let sourceType: LectureSourceType
    let status: LectureStatus
    let hasFolder: Bool

    init(lecture: Lecture) {
        self.lectureID = lecture.id
        self.sourceType = lecture.sourceType
        self.status = lecture.status
        self.hasFolder = lecture.folderID != nil
    }
}
