import Foundation
import SwiftData

@Model
final class CachedLectureRecord {
    @Attribute(.unique) var cacheKey: String
    var ownerUserID: String
    var remoteID: String
    var title: String = ""
    var summaryShort: String = ""
    var transcriptPreview: String = ""
    var folderRemoteID: String?
    var createdAt: Date
    var payload: Data
    /// Name of the lecture's audio file in `Documents/Recordings`, if it was
    /// recorded or imported on this device. Stored instead of an absolute URL
    /// because the app container path changes between installs.
    var audioFileName: String?

    init(
        ownerUserID: String,
        remoteID: String,
        title: String,
        summaryShort: String,
        transcriptPreview: String,
        folderRemoteID: String?,
        createdAt: Date,
        payload: Data,
        audioFileName: String? = nil
    ) {
        self.cacheKey = Self.cacheKey(ownerUserID: ownerUserID, remoteID: remoteID)
        self.ownerUserID = ownerUserID
        self.remoteID = remoteID
        self.title = title
        self.summaryShort = summaryShort
        self.transcriptPreview = transcriptPreview
        self.folderRemoteID = folderRemoteID
        self.createdAt = createdAt
        self.payload = payload
        self.audioFileName = audioFileName
    }

    static func cacheKey(ownerUserID: String, remoteID: String) -> String {
        "\(ownerUserID)|\(remoteID)"
    }
}
