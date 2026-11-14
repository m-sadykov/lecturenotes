import CoreTransferable
import FirebaseStorage
import Foundation
import UniformTypeIdentifiers

/// A lecture's audio for `ShareLink`. Uses the file on the device when it exists,
/// otherwise downloads the recording from Firebase Storage when the share sheet asks
/// for it, and keeps that download in the temporary directory for later shares.
/// Recordings uploaded in chunks are downloaded part by part and joined into one file.
struct LectureAudioShareItem: Transferable {
    let source: LectureAudioSource
    /// Base name for the shared file, without an extension.
    let fileName: String

    /// Returns `nil` when the lecture has neither a local file nor an uploaded copy.
    init?(lecture: Lecture, fileManager: FileManager = .default) {
        guard let source = LectureAudioSource(lecture: lecture, fileManager: fileManager) else {
            return nil
        }

        self.source = source
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
        case .remote(let paths):
            // The share sheet can ask for the file several times (when it opens and
            // again for the chosen action), so reuse an earlier download.
            let destination = Self.cachedFileURL(forRemotePaths: paths, fileName: fileName)
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: destination.path(percentEncoded: false)) {
                return destination
            }

            try fileManager.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            if paths.count == 1, let path = paths.first {
                let temporaryURL = try await Self.download(path: path)
                Self.moveIntoPlace(temporaryURL, destination: destination)
                return destination
            }

            // Chunked upload: download every part, then join them into one .m4a.
            var partURLs: [URL] = []
            defer {
                for partURL in partURLs {
                    try? fileManager.removeItem(at: partURL)
                }
            }
            for path in paths {
                partURLs.append(try await Self.download(path: path))
            }

            let joinedURL = fileManager.temporaryDirectory
                .appending(path: UUID().uuidString)
                .appendingPathExtension("m4a")
            try await LectureAudioComposer.exportJoinedAudio(from: partURLs, to: joinedURL)
            Self.moveIntoPlace(joinedURL, destination: destination)
            return destination
        }
    }

    /// Downloads a Storage object to a temporary file that keeps the object's extension,
    /// so AVFoundation can read it.
    private static func download(path: String) async throws -> URL {
        let downloadURL = try await Storage.storage().reference(withPath: path).downloadURL()
        let (temporaryURL, _) = try await URLSession.shared.download(from: downloadURL)
        let fileExtension = URL(filePath: path).pathExtension
        let namedURL = temporaryURL
            .deletingPathExtension()
            .appendingPathExtension(fileExtension.isEmpty ? "m4a" : fileExtension)
        try FileManager.default.moveItem(at: temporaryURL, to: namedURL)
        return namedURL
    }

    private static func moveIntoPlace(_ fileURL: URL, destination: URL) {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path(percentEncoded: false)) {
            // Another request finished the same file first.
            try? fileManager.removeItem(at: fileURL)
        } else {
            try? fileManager.moveItem(at: fileURL, to: destination)
        }
    }

    /// Stable location in the temporary directory for a downloaded recording: one folder
    /// per remote recording, holding a file named after the lecture. A chunked recording
    /// is keyed by the folder that holds its chunks and is always joined into an `.m4a`.
    static func cachedFileURL(forRemotePaths paths: [String], fileName: String) -> URL {
        let key: String
        let fileExtension: String
        if paths.count > 1, let firstPath = paths.first {
            key = URL(filePath: firstPath).deletingLastPathComponent().path(percentEncoded: false)
            fileExtension = "m4a"
        } else {
            key = paths.first ?? ""
            fileExtension = URL(filePath: key).pathExtension
        }

        let folderName = key
            .replacing("/", with: "_")
            .replacing(":", with: "_")

        return URL.temporaryDirectory
            .appending(path: "SharedLectureAudio", directoryHint: .isDirectory)
            .appending(path: folderName, directoryHint: .isDirectory)
            .appending(path: fileName)
            .appendingPathExtension(fileExtension.isEmpty ? "m4a" : fileExtension)
    }
}
