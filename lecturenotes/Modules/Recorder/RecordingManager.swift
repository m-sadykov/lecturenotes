import AVFoundation
import Foundation

@MainActor
final class RecordingManager {
    struct RecordingCapture {
        let url: URL
        let createdAt: Date
        let duration: Duration
    }

    enum RecordingError: LocalizedError {
        case microphoneAccessDenied
        case recorderUnavailable

        var errorDescription: String? {
            switch self {
            case .microphoneAccessDenied:
                "Microphone access is required to start recording."
            case .recorderUnavailable:
                "Unable to create an audio recorder."
            }
        }
    }

    private var recorder: AVAudioRecorder?
    private let session = AVAudioSession.sharedInstance()
    private var currentOutputURL: URL?
    private var startedAt: Date?

    func startRecording() async throws {
        try await configureSessionIfNeeded()

        let outputURL = makeOutputURL()
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: outputURL, settings: settings)
        recorder.isMeteringEnabled = true

        guard recorder.record() else {
            throw RecordingError.recorderUnavailable
        }

        currentOutputURL = outputURL
        startedAt = .now
        self.recorder = recorder
    }

    func pauseRecording() {
        recorder?.pause()
    }

    func resumeRecording() {
        recorder?.record()
    }

    func stopRecording() -> RecordingCapture? {
        guard let activeRecorder = recorder, let currentOutputURL else {
            return nil
        }

        let duration = Duration.seconds(activeRecorder.currentTime)
        let createdAt = startedAt ?? .now
        activeRecorder.stop()
        self.recorder = nil
        self.currentOutputURL = nil
        startedAt = nil
        deactivateSession()
        return RecordingCapture(url: currentOutputURL, createdAt: createdAt, duration: duration)
    }

    func discardRecording() {
        guard let recorder, let currentOutputURL else {
            return
        }

        recorder.stop()
        self.recorder = nil
        self.currentOutputURL = nil
        startedAt = nil
        try? FileManager.default.removeItem(at: currentOutputURL)
        deactivateSession()
    }

    private func configureSessionIfNeeded() async throws {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            break
        case .undetermined:
            let isGranted = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission(completionHandler: { isGranted in
                    continuation.resume(returning: isGranted)
                })
            }
            guard isGranted else {
                throw RecordingError.microphoneAccessDenied
            }
        case .denied:
            throw RecordingError.microphoneAccessDenied
        @unknown default:
            throw RecordingError.microphoneAccessDenied
        }

        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
    }

    private func deactivateSession() {
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func makeOutputURL() -> URL {
        URL.documentsDirectory
            .appending(path: "Recordings", directoryHint: .isDirectory)
            .appending(path: "recording-\(UUID().uuidString)")
            .appendingPathExtension("m4a")
    }
}
