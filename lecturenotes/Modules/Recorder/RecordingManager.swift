import AVFoundation
import Foundation

@MainActor
final class RecordingManager {
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

    func startRecording() async throws {
        try await configureSessionIfNeeded()

        let outputURL = makeOutputURL()
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

        self.recorder = recorder
    }

    func pauseRecording() {
        recorder?.pause()
    }

    func resumeRecording() {
        recorder?.record()
    }

    func stopRecording() {
        recorder?.stop()
        recorder = nil
        deactivateSession()
    }

    private func configureSessionIfNeeded() async throws {
        switch session.recordPermission {
        case .granted:
            break
        case .undetermined:
            let isGranted = await withCheckedContinuation { continuation in
                session.requestRecordPermission { isGranted in
                    continuation.resume(returning: isGranted)
                }
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
            .appending(path: "recording-\(UUID().uuidString)")
            .appendingPathExtension("m4a")
    }
}
