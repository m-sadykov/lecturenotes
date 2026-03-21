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

    init(
        ownerUserID: String,
        remoteID: String,
        title: String,
        summaryShort: String,
        transcriptPreview: String,
        folderRemoteID: String?,
        createdAt: Date,
        payload: Data
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
    }

    static func cacheKey(ownerUserID: String, remoteID: String) -> String {
        "\(ownerUserID)|\(remoteID)"
    }
}
