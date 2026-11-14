import Foundation

/// Where a lecture's audio comes from for playback and sharing.
///
/// Recordings longer than 15 minutes are uploaded as several `chunk_N.m4a` files and
/// `Lecture.remoteAudioPath` points at the first one, so the remote case carries every
/// part, in playback order, and callers join them into one recording.
enum LectureAudioSource: Equatable {
    case local(URL)
    case remote(paths: [String])

    /// Returns `nil` when the lecture has neither a local file nor an uploaded copy.
    init?(
        localURL: URL?,
        remoteAudioPath: String?,
        remoteAudioChunkPaths: [String]?,
        fileExists: (URL) -> Bool
    ) {
        if let localURL, localURL.isFileURL, fileExists(localURL) {
            self = .local(localURL)
            return
        }

        let chunkPaths = (remoteAudioChunkPaths ?? []).filter { !$0.isEmpty }
        if chunkPaths.count > 1 {
            self = .remote(paths: Self.sortedByChunkNumber(chunkPaths))
        } else if let remoteAudioPath, !remoteAudioPath.isEmpty {
            self = .remote(paths: [remoteAudioPath])
        } else if let onlyChunk = chunkPaths.first {
            self = .remote(paths: [onlyChunk])
        } else {
            return nil
        }
    }

    init?(lecture: Lecture, fileManager: FileManager = .default) {
        self.init(
            localURL: lecture.audioURL,
            remoteAudioPath: lecture.remoteAudioPath,
            remoteAudioChunkPaths: lecture.remoteAudioChunkPaths,
            fileExists: { fileManager.fileExists(atPath: $0.path(percentEncoded: false)) }
        )
    }

    /// Orders `…/chunk_N.m4a` paths by `N` numerically, so `chunk_10` follows `chunk_9`.
    /// Paths without a chunk number keep their relative order after the numbered ones.
    static func sortedByChunkNumber(_ paths: [String]) -> [String] {
        paths.enumerated()
            .sorted { lhs, rhs in
                switch (chunkNumber(in: lhs.element), chunkNumber(in: rhs.element)) {
                case let (left?, right?) where left != right:
                    left < right
                case (.some, .none):
                    true
                case (.none, .some):
                    false
                default:
                    lhs.offset < rhs.offset
                }
            }
            .map(\.element)
    }

    private static func chunkNumber(in path: String) -> Int? {
        let fileName = URL(filePath: path).deletingPathExtension().lastPathComponent
        guard fileName.hasPrefix("chunk_") else {
            return nil
        }

        return Int(fileName.dropFirst("chunk_".count))
    }
}
