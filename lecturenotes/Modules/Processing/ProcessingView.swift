import SwiftUI

struct ProcessingView: View {
    let lecture: Lecture
    let isRetrying: Bool
    let onRetry: (() -> Void)?

    init(
        lecture: Lecture,
        isRetrying: Bool = false,
        onRetry: (() -> Void)? = nil
    ) {
        self.lecture = lecture
        self.isRetrying = isRetrying
        self.onRetry = onRetry
    }

    var body: some View {
        VStack(spacing: 18) {
            ProcessingHeroView(
                title: headlineTitle,
                message: statusMessage,
                progress: inferredProgress,
                isFailed: lecture.status == .failed
            )
            .padding(.horizontal, 28)
            .padding(.top, 16)

            if lecture.status == .failed, let onRetry {
                Button(action: onRetry) {
                    HStack(spacing: 10) {
                        if isRetrying {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }

                        Text(isRetrying ? "Retrying..." : "Retry")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(.black)
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            } else {
                Spacer(minLength: 40)

                Text(footerMessage)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.bottom, 32)
        .background(Color(.systemGray6))
    }

    private var statusMessage: String {
        switch lecture.status {
        case .draft:
            "Preparing your recording."
        case .uploading:
            "Uploading your recording."
        case .transcribing:
            "Converting your speech to text. This may take a moment."
        case .generating:
            "Creating the summary, flashcards, and quiz."
        case .ready:
            "Your note is fully processed and ready to explore."
        case .failed:
            "We couldn't finish processing this recording."
        }
    }

    private var headlineTitle: String {
        switch lecture.status {
        case .failed:
            "Transcription Failed"
        case .ready:
            "Your Recording Is Ready"
        case .uploading:
            "Uploading..."
        case .transcribing:
            "Transcribing..."
        case .generating:
            "Generating Notes..."
        case .draft:
            "Preparing..."
        }
    }

    private var footerMessage: String {
        switch lecture.status {
        case .uploading:
            "Uploading your recording so processing can begin."
        case .transcribing:
            "Listening for the important concepts and turning them into text."
        case .generating:
            "Transforming the transcript into a polished study note."
        case .ready:
            "You can now open the summary, transcript, flashcards, and quiz."
        case .failed:
            lecture.processingErrorMessage ?? "Processing failed."
        case .draft:
            "Getting everything ready."
        }
    }

    private var inferredProgress: Double {
        switch lecture.status {
        case .draft:
            0.08
        case .uploading:
            0.24
        case .transcribing:
            0.58
        case .generating:
            0.84
        case .ready:
            1
        case .failed:
            0.58
        }
    }

}

private struct ProcessingHeroView: View {
    let title: String
    let message: String
    let progress: Double
    let isFailed: Bool

    var body: some View {
        VStack(spacing: 22) {
            if isFailed {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 112, height: 112)

                    Circle()
                        .stroke(Color.red.opacity(0.16), lineWidth: 1)
                        .frame(width: 132, height: 132)

                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(Color.red)
                }
                .padding(.top, 8)
            } else {
                ProgressView()
                    .controlSize(.regular)
                    .tint(.black)
                    .scaleEffect(1.65)
                    .padding(.top, 8)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3)
                    .bold()
                    .multilineTextAlignment(.center)

                Text("\(Int(progress * 100))% complete")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.black.opacity(0.08))

                        Capsule()
                            .fill(.black)
                            .frame(width: max(geometry.size.width * progress, 20))
                    }
                }
                .frame(height: 7)

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Transcribing") {
    ProcessingView(lecture: processingPreviewLecture(status: .transcribing))
}

#Preview("Generating") {
    ProcessingView(lecture: processingPreviewLecture(status: .generating))
}

#Preview("Failed") {
    ProcessingView(
        lecture: processingPreviewLecture(
            status: .failed,
            processingErrorMessage: "No speech detected. Try speaking louder or recording for longer."
        )
    )
}

#Preview("Ready") {
    ProcessingView(lecture: processingPreviewLecture(status: .ready))
}

private func processingPreviewLecture(
    status: LectureStatus,
    processingErrorMessage: String? = nil
) -> Lecture {
    Lecture(
        title: "New Recording",
        course: "Biology 101",
        createdAt: Date(timeIntervalSinceReferenceDate: 794_855_467),
        duration: .seconds(3),
        status: status,
        transcript: status == .ready ? "Photosynthesis converts light into chemical energy." : "",
        summaryShort: status == .ready ? "Lecture about photosynthesis basics." : "",
        summaryLong: status == .ready ? "This lecture explains how plants convert sunlight into stored chemical energy and why chlorophyll matters." : "",
        flashcards: [],
        quiz: [],
        processingErrorMessage: processingErrorMessage
    )
}
