import Foundation

/// Maps lectures to their audio files in `Documents/Recordings`.
///
/// Absolute file URLs are not stable on iOS: the app's data container moves
/// between installs and updates, so any persisted absolute path eventually
/// points nowhere. This type persists only the file name and rebuilds the URL
/// from the current recordings directory whenever a lecture is read.
nonisolated struct LectureLocalAudioStore {
    let recordingsDirectory: URL
    private let fileManager: FileManager

    init(
        recordingsDirectory: URL = Self.defaultRecordingsDirectory,
        fileManager: FileManager = .default
    ) {
        self.recordingsDirectory = recordingsDirectory
        self.fileManager = fileManager
    }

    static var defaultRecordingsDirectory: URL {
        URL.documentsDirectory.appending(path: "Recordings", directoryHint: .isDirectory)
    }

    /// The file name to persist for a local audio URL.
    ///
    /// Only the last path component is kept, so a URL from an earlier
    /// container (`.../Application/<old UUID>/Documents/Recordings/x.m4a`)
    /// still maps to `x.m4a` in the current recordings directory.
    func fileName(for audioURL: URL?) -> String? {
        guard let audioURL, audioURL.isFileURL else {
            return nil
        }

        let fileName = audioURL.lastPathComponent
        return fileName.isEmpty || fileName == "/" ? nil : fileName
    }

    /// The URL of a file in the recordings directory, or `nil` if the file is missing.
    func existingFileURL(named fileName: String?) -> URL? {
        guard let fileName, !fileName.isEmpty else {
            return nil
        }

        let url = recordingsDirectory.appending(path: fileName, directoryHint: .notDirectory)
        return fileManager.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
    }

    /// File names in the recordings directory that are named after a lecture ID
    /// (`<lecture UUID>.<ext>`, the naming used for imported audio), keyed by
    /// the uppercase UUID string.
    ///
    /// Microphone recordings are named `recording-<UUID>.m4a` with a UUID that
    /// is unrelated to the lecture ID, so they never appear here and are never
    /// guessed.
    func lectureIDNamedFiles() -> [String: String] {
        let fileNames = (try? fileManager.contentsOfDirectory(atPath: recordingsDirectory.path(percentEncoded: false))) ?? []

        return fileNames.reduce(into: [String: String]()) { result, fileName in
            let baseName = URL(filePath: fileName).deletingPathExtension().lastPathComponent
            guard let lectureID = UUID(uuidString: baseName) else {
                return
            }

            result[lectureID.uuidString] = fileName
        }
    }
}
