import CoreTransferable
import FirebaseStorage
import Foundation
import UniformTypeIdentifiers

/// A lecture's audio for `ShareLink`. Uses the file on the device when it exists,
/// otherwise downloads the recording from Firebase Storage when the share sheet asks
/// for it, and keeps that download in the temporary directory for later shares.
struct LectureAudioShareItem: Transferable {
    enum Source: Equatable {
        case local(URL)
        case remote(path: String)
    }

    let source: Source
    /// Base name for the shared file, without an extension.
    let fileName: String

    /// Returns `nil` when the lecture has neither a local file nor an uploaded copy.
    init?(lecture: Lecture, fileManager: FileManager = .default) {
        if let localURL = lecture.audioURL, fileManager.fileExists(atPath: localURL.path(percentEncoded: false)) {
            source = .local(localURL)
        } else if let remotePath = lecture.remoteAudioPath, !remotePath.isEmpty {
            source = .remote(path: remotePath)
        } else {
            return nil
        }

        fileName = Self.sanitizedFileName(lecture.displayTitle)
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .audio) { item in
            SentTransferredFile(try await item.fileURL())
        }
    }

    /// File name safe for the file system: path separators and colons removed,
    /// whitespace trimmed, with a fallback for empty titles.
    static func sanitizedFileName(_ title: String) -> String {
        let cleaned = title
            .replacing("/", with: "-")
            .replacing(":", with: " -")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Lecture" : cleaned
    }

    private func fileURL() async throws -> URL {
        switch source {
        case .local(let url):
            return url
        case .remote(let path):
            // The share sheet can ask for the file several times (when it opens and
            // again for the chosen action), so reuse an earlier download of this path.
            let destination = Self.cachedFileURL(forRemotePath: path, fileName: fileName)
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: destination.path(percentEncoded: false)) {
                return destination
            }

            let downloadURL = try await Storage.storage().reference(withPath: path).downloadURL()
            let (temporaryURL, _) = try await URLSession.shared.download(from: downloadURL)

            try fileManager.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if fileManager.fileExists(atPath: destination.path(percentEncoded: false)) {
                // Another request finished the same download first.
                try? fileManager.removeItem(at: temporaryURL)
            } else {
                try fileManager.moveItem(at: temporaryURL, to: destination)
            }
            return destination
        }
    }

    /// Stable location in the temporary directory for a downloaded recording: one folder
    /// per remote path, holding a file named after the lecture.
    static func cachedFileURL(forRemotePath path: String, fileName: String) -> URL {
        let folderName = path
            .replacing("/", with: "_")
            .replacing(":", with: "_")
        let fileExtension = URL(filePath: path).pathExtension

        return URL.temporaryDirectory
            .appending(path: "SharedLectureAudio", directoryHint: .isDirectory)
            .appending(path: folderName, directoryHint: .isDirectory)
            .appending(path: fileName)
            .appendingPathExtension(fileExtension.isEmpty ? "m4a" : fileExtension)
    }
}
