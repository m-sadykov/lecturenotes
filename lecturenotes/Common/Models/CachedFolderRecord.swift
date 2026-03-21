import Foundation
import SwiftData

@Model
final class CachedFolderRecord {
    @Attribute(.unique) var cacheKey: String
    var ownerUserID: String
    var remoteID: String
    var name: String
    var createdAt: Date

    init(
        ownerUserID: String,
        remoteID: String,
        name: String,
        createdAt: Date
    ) {
        self.cacheKey = Self.cacheKey(ownerUserID: ownerUserID, remoteID: remoteID)
        self.ownerUserID = ownerUserID
        self.remoteID = remoteID
        self.name = name
        self.createdAt = createdAt
    }

    static func cacheKey(ownerUserID: String, remoteID: String) -> String {
        "\(ownerUserID)|\(remoteID)"
    }
}
