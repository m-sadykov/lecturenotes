import AVFoundation
import Foundation
import UIKit

@MainActor
final class RecordingManager: NSObject, AVAudioRecorderDelegate {
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
                String(localized: "Microphone access is required to start recording.")
            case .recorderUnavailable:
                String(localized: "Unable to create an audio recorder.")
            }
        }
    }

    private var recorder: AVAudioRecorder?
    private let session = AVAudioSession.sharedInstance()
    private var currentOutputURL: URL?
    private var startedAt: Date?
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var notificationObservers: [NSObjectProtocol] = []
    private var shouldResumeAfterInterruption = false

    var onSystemPause: ((String) -> Void)?

    override init() {
        super.init()
        observeApplicationLifecycle()
        observeAudioSessionLifecycle()
    }

    deinit {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }

        let backgroundTaskIdentifier = self.backgroundTaskIdentifier
        guard backgroundTaskIdentifier != .invalid else {
            return
        }

        Task { @MainActor in
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        }
    }

    var currentDuration: Duration {
        Duration.seconds(recorder?.currentTime ?? 0)
    }

    var isRecording: Bool {
        recorder?.isRecording == true
    }

    func startRecording() async throws {
        try await requestRecordPermissionIfNeeded()
        try activateSessionForRecording()

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
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()

        guard recorder.record() else {
            throw RecordingError.recorderUnavailable
        }

        currentOutputURL = outputURL
        startedAt = .now
        self.recorder = recorder
        shouldResumeAfterInterruption = false
    }

    func pauseRecording() {
        shouldResumeAfterInterruption = false
        recorder?.pause()
    }

    func resumeRecording() {
        try? activateSessionForRecording()
        recorder?.record()
    }

    func prepareForBackgroundRecording() {
        guard recorder != nil else {
            return
        }

        beginBackgroundTaskIfNeeded()
    }

    func refreshAfterForeground() {
        guard recorder != nil else {
            return
        }

        endBackgroundTaskIfNeeded()
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
        shouldResumeAfterInterruption = false
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
        shouldResumeAfterInterruption = false
        try? FileManager.default.removeItem(at: currentOutputURL)
        deactivateSession()
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        guard !flag else {
            return
        }

        Task { @MainActor [weak self] in
            guard let self, recorder === self.recorder else {
                return
            }

            self.onSystemPause?(String(localized: "Recording was stopped by the system."))
        }
    }

    private func requestRecordPermissionIfNeeded() async throws {
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
    }

    private func activateSessionForRecording() throws {
        try session.setCategory(.record, mode: .measurement, options: [.allowBluetoothHFP])
        try session.setActive(true)
    }

    private func deactivateSession() {
        endBackgroundTaskIfNeeded()
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func observeApplicationLifecycle() {
        let didEnterBackgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.prepareForBackgroundRecording()
            }
        }

        let didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAfterForeground()
            }
        }

        notificationObservers.append(didEnterBackgroundObserver)
        notificationObservers.append(didBecomeActiveObserver)
    }

    private func observeAudioSessionLifecycle() {
        let interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            let interruptionTypeRawValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let interruptionOptionsRawValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor [weak self] in
                self?.handleAudioSessionInterruption(
                    interruptionTypeRawValue: interruptionTypeRawValue,
                    interruptionOptionsRawValue: interruptionOptionsRawValue
                )
            }
        }

        let routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            let routeChangeReasonRawValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor [weak self] in
                self?.handleAudioRouteChange(reasonRawValue: routeChangeReasonRawValue)
            }
        }

        let mediaServicesResetObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: session,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleMediaServicesReset()
            }
        }

        notificationObservers.append(interruptionObserver)
        notificationObservers.append(routeChangeObserver)
        notificationObservers.append(mediaServicesResetObserver)
    }

    private func handleAudioSessionInterruption(
        interruptionTypeRawValue: UInt?,
        interruptionOptionsRawValue: UInt?
    ) {
        guard recorder != nil,
              let interruptionTypeRawValue,
              let interruptionType = AVAudioSession.InterruptionType(rawValue: interruptionTypeRawValue) else {
            return
        }

        switch interruptionType {
        case .began:
            shouldResumeAfterInterruption = isRecording
            recorder?.pause()
            onSystemPause?("Recording was paused by the system.")
        case .ended:
            let optionsRawValue = interruptionOptionsRawValue ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsRawValue)

            do {
                try activateSessionForRecording()
                if shouldResumeAfterInterruption && options.contains(.shouldResume) {
                    recorder?.record()
                }
            } catch {
                onSystemPause?(error.localizedDescription)
            }

            shouldResumeAfterInterruption = false
        @unknown default:
            shouldResumeAfterInterruption = false
        }
    }

    private func handleAudioRouteChange(reasonRawValue: UInt?) {
        guard recorder != nil,
              let reasonRawValue,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRawValue) else {
            return
        }

        switch reason {
        case .oldDeviceUnavailable:
            try? activateSessionForRecording()
        default:
            break
        }
    }

    private func handleMediaServicesReset() {
        guard recorder != nil else {
            return
        }

        do {
            try activateSessionForRecording()
            recorder?.record()
        } catch {
            onSystemPause?(error.localizedDescription)
        }
    }

    private func beginBackgroundTaskIfNeeded() {
        guard backgroundTaskIdentifier == .invalid else {
            return
        }

        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "LectureRecording") { [weak self] in
            Task { @MainActor [weak self] in
                self?.endBackgroundTaskIfNeeded()
            }
        }
    }

    private func endBackgroundTaskIfNeeded() {
        guard backgroundTaskIdentifier != .invalid else {
            return
        }

        UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        backgroundTaskIdentifier = .invalid
    }

    private func makeOutputURL() -> URL {
        URL.documentsDirectory
            .appending(path: "Recordings", directoryHint: .isDirectory)
            .appending(path: "recording-\(UUID().uuidString)")
            .appendingPathExtension("m4a")
    }
}
