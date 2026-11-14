@preconcurrency import AVFoundation
import FirebaseStorage
import Foundation

/// Joins the parts of a chunked lecture recording into one continuous asset.
@MainActor
enum LectureAudioComposer {
    /// Download URLs for Firebase Storage paths, in the same order.
    static func downloadURLs(for paths: [String], storage: Storage = .storage()) async throws -> [URL] {
        var urls: [URL] = []
        urls.reserveCapacity(paths.count)

        for path in paths {
            urls.append(try await storage.reference(withPath: path).downloadURL())
        }

        return urls
    }

    /// One asset for the given audio files: the file itself when there is one, otherwise
    /// a composition that plays them back to back on a single timeline.
    static func asset(joining urls: [URL]) async throws -> AVAsset {
        if urls.count == 1, let url = urls.first {
            return AVURLAsset(url: url)
        }

        let composition = AVMutableComposition()
        guard let compositionTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw LectureAudioComposerError.unableToJoinAudio
        }

        var cursor = CMTime.zero
        for url in urls {
            let partAsset = AVURLAsset(url: url)
            let partDuration = try await partAsset.load(.duration)
            guard let partTrack = try await partAsset.loadTracks(withMediaType: .audio).first else {
                continue
            }

            try compositionTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: partDuration),
                of: partTrack,
                at: cursor
            )
            cursor = cursor + partDuration
        }

        guard cursor > .zero else {
            throw LectureAudioComposerError.unableToJoinAudio
        }

        return composition
    }

    /// Writes the joined parts to a single `.m4a` file at `destination`.
    static func exportJoinedAudio(from urls: [URL], to destination: URL) async throws {
        let asset = try await asset(joining: urls)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw LectureAudioComposerError.unableToJoinAudio
        }

        session.outputURL = destination
        session.outputFileType = .m4a

        let sessionBox = ExportSessionBox(session)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.exportAsynchronously {
                if sessionBox.session.status == .completed {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: sessionBox.session.error ?? LectureAudioComposerError.unableToJoinAudio)
                }
            }
        }
    }
}

enum LectureAudioComposerError: LocalizedError {
    case unableToJoinAudio

    var errorDescription: String? {
        String(appLocalized: "Unable to prepare audio for processing.")
    }
}

private final class ExportSessionBox: @unchecked Sendable {
    let session: AVAssetExportSession

    init(_ session: AVAssetExportSession) {
        self.session = session
    }
}
