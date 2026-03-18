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
            switch lecture.sourceType {
            case .audio:
                "Preparing your recording."
            case .text:
                "Preparing your text import."
            case .youtube:
                "Preparing your YouTube import."
            }
        case .uploading:
            switch lecture.sourceType {
            case .audio:
                "Uploading your recording."
            case .text:
                "Saving your text for processing."
            case .youtube:
                "Checking your YouTube video."
            }
        case .transcribing:
            switch lecture.sourceType {
            case .audio:
                "Converting your speech to text. This may take a moment."
            case .text:
                "Preparing your text for note generation."
            case .youtube:
                "Fetching captions for the YouTube video."
            }
        case .generating:
            "Creating the summary, flashcards, and quiz."
        case .ready:
            "Your note is fully processed and ready to explore."
        case .failed:
            switch lecture.sourceType {
            case .audio:
                "We couldn't finish processing this recording."
            case .text:
                "We couldn't finish processing this text import."
            case .youtube:
                "We couldn't finish processing this YouTube video."
            }
        }
    }

    private var headlineTitle: String {
        switch lecture.status {
        case .failed:
            lecture.sourceType == .audio ? "Transcription Failed" : "Processing Failed"
        case .ready:
            switch lecture.sourceType {
            case .audio:
                "Your Recording Is Ready"
            case .text:
                "Your Text Import Is Ready"
            case .youtube:
                "Your YouTube Import Is Ready"
            }
        case .uploading:
            "Uploading..."
        case .transcribing:
            lecture.sourceType == .audio ? "Transcribing..." : "Preparing..."
        case .generating:
            "Generating Notes..."
        case .draft:
            "Preparing..."
        }
    }

    private var footerMessage: String {
        switch lecture.status {
        case .uploading:
            switch lecture.sourceType {
            case .audio:
                "Uploading your recording so processing can begin."
            case .text:
                "Saving your text so processing can begin."
            case .youtube:
                "Saving your YouTube source so processing can begin."
            }
        case .transcribing:
            switch lecture.sourceType {
            case .audio:
                "Listening for the important concepts and turning them into text."
            case .text:
                "Reviewing the imported text before creating study materials."
            case .youtube:
                "Trying to convert YouTube captions into transcript text for your study materials."
            }
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
        sourceType: .audio,
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
