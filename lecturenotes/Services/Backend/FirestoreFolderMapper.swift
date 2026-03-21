import FirebaseFirestore
import Foundation

enum FirestoreFolderMapper {
    static func documentData(for folder: LectureFolder) -> [String: Any] {
        [
            "id": folder.id.uuidString,
            "name": folder.name,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }

    static func folder(from data: [String: Any], fallbackDocumentID: String) -> LectureFolder? {
        let folderID = UUID(uuidString: stringValue(for: "id", in: data) ?? fallbackDocumentID)
        guard let folderID else {
            return nil
        }

        return LectureFolder(
            id: folderID,
            name: stringValue(for: "name", in: data) ?? "Folder"
        )
    }

    static func createdAt(from data: [String: Any]) -> Date {
        if let timestamp = data["createdAt"] as? Timestamp {
            return timestamp.dateValue()
        }

        if let date = data["createdAt"] as? Date {
            return date
        }

        return .now
    }

    private static func stringValue(for key: String, in data: [String: Any]) -> String? {
        data[key] as? String
    }
}
