@preconcurrency import AVFoundation
import Foundation

struct LectureAudioChunker {
    let maximumSingleUploadDuration: Duration = .seconds(15 * 60)

    func makeUploadPlan(for lecture: Lecture, userID: String) async throws -> LectureAudioUploadPlan {
        guard let audioURL = lecture.audioURL else {
            throw FirebaseLectureProcessingError.missingAudioFile
        }

        if lecture.duration <= maximumSingleUploadDuration {
            let fileFormat = LectureAudioFormat(url: audioURL)
            let storagePath = "audio/\(userID)/\(lecture.id.uuidString).\(fileFormat.fileExtension)"
            return .single(
                LectureAudioUploadItem(
                    fileURL: audioURL,
                    storagePath: storagePath,
                    mimeType: fileFormat.mimeType,
                    isTemporary: false
                )
            )
        }

        let chunkURLs = try await splitAudio(at: audioURL, lectureID: lecture.id, totalDuration: lecture.duration)
        let items = chunkURLs.enumerated().map { index, chunkURL in
            LectureAudioUploadItem(
                fileURL: chunkURL,
                storagePath: "audio/\(userID)/\(lecture.id.uuidString)/chunk_\(index + 1).m4a",
                mimeType: "audio/mp4",
                isTemporary: true
            )
        }

        return .chunked(items)
    }

    func cleanup(plan: LectureAudioUploadPlan) {
        let fileManager = FileManager.default

        for item in plan.items where item.isTemporary {
            try? fileManager.removeItem(at: item.fileURL)
        }

        if case .chunked(let items) = plan,
           let directoryURL = items.first?.fileURL.deletingLastPathComponent() {
            try? fileManager.removeItem(at: directoryURL)
        }
    }

    private func splitAudio(at audioURL: URL, lectureID: UUID, totalDuration: Duration) async throws -> [URL] {
        let asset = AVURLAsset(url: audioURL)
        let chunkLength = maximumSingleUploadDuration.timeInterval
        let totalSeconds = max(totalDuration.timeInterval, 1)
        let chunkCount = max(1, Int(ceil(totalSeconds / chunkLength)))
        let outputDirectory = URL.documentsDirectory
            .appending(path: "ProcessingChunks", directoryHint: .isDirectory)
            .appending(path: lectureID.uuidString, directoryHint: .isDirectory)

        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        var outputURLs: [URL] = []
        outputURLs.reserveCapacity(chunkCount)

        for chunkIndex in 0..<chunkCount {
            let startSeconds = Double(chunkIndex) * chunkLength
            let chunkDuration = min(chunkLength, totalSeconds - startSeconds)
            let outputURL = outputDirectory
                .appending(path: "chunk_\(chunkIndex + 1)")
                .appendingPathExtension("m4a")

            if FileManager.default.fileExists(atPath: outputURL.path(percentEncoded: false)) {
                try FileManager.default.removeItem(at: outputURL)
            }

            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
                throw LectureAudioChunkerError.unableToCreateExportSession
            }

            exportSession.outputURL = outputURL
            exportSession.outputFileType = .m4a
            exportSession.timeRange = CMTimeRange(
                start: CMTime(seconds: startSeconds, preferredTimescale: 600),
                duration: CMTime(seconds: chunkDuration, preferredTimescale: 600)
            )

            try await export(session: exportSession)
            outputURLs.append(outputURL)
        }

        return outputURLs
    }

    private func export(session: AVAssetExportSession) async throws {
        let sessionBox = ExportSessionBox(session)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.exportAsynchronously {
                switch sessionBox.session.status {
                case .completed:
                    continuation.resume(returning: ())
                case .failed:
                    continuation.resume(
                        throwing: sessionBox.session.error ?? LectureAudioChunkerError.exportFailed
                    )
                case .cancelled:
                    continuation.resume(throwing: LectureAudioChunkerError.exportCancelled)
                default:
                    continuation.resume(throwing: LectureAudioChunkerError.exportFailed)
                }
            }
        }
    }
}

private final class ExportSessionBox: @unchecked Sendable {
    let session: AVAssetExportSession

    init(_ session: AVAssetExportSession) {
        self.session = session
    }
}

struct LectureAudioFormat {
    let fileExtension: String
    let mimeType: String

    init(url: URL) {
        switch url.pathExtension.lowercased() {
        case "mp3", "mpeg":
            fileExtension = "mp3"
            mimeType = "audio/mpeg"
        case "wav":
            fileExtension = "wav"
            mimeType = "audio/wav"
        case "mp4":
            fileExtension = "mp4"
            mimeType = "audio/mp4"
        case "m4a":
            fileExtension = "m4a"
            mimeType = "audio/mp4"
        default:
            fileExtension = "m4a"
            mimeType = "audio/mp4"
        }
    }
}

enum LectureAudioUploadPlan {
    case single(LectureAudioUploadItem)
    case chunked([LectureAudioUploadItem])

    var items: [LectureAudioUploadItem] {
        switch self {
        case .single(let item):
            [item]
        case .chunked(let items):
            items
        }
    }

    var primaryAudioPath: String? {
        items.first?.storagePath
    }

    var chunkPaths: [String] {
        items.map(\.storagePath)
    }

    var isChunked: Bool {
        switch self {
        case .single:
            false
        case .chunked:
            true
        }
    }
}

struct LectureAudioUploadItem {
    let fileURL: URL
    let storagePath: String
    let mimeType: String
    let isTemporary: Bool
}

enum LectureAudioChunkerError: LocalizedError {
    case unableToCreateExportSession
    case exportFailed
    case exportCancelled

    var errorDescription: String? {
        switch self {
        case .unableToCreateExportSession:
            "Unable to prepare audio for processing."
        case .exportFailed:
            "Unable to split the audio into processing chunks."
        case .exportCancelled:
            "Audio splitting was cancelled."
        }
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        TimeInterval(components.seconds) + (TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000)
    }
}
