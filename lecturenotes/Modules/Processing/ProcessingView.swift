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
                                .tint(AppColor.onInk)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }

                        if isRetrying {
                            Text("Retrying...")
                        } else {
                            Text("Retry")
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(AppColor.onInk)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(AppColor.ink)
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            } else {
                Spacer(minLength: 40)

                footerMessageView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.bottom, 32)
        .background(AppColor.canvas)
    }

    private var statusMessage: LocalizedStringResource {
        switch lecture.status {
        case .draft:
            switch lecture.sourceType {
            case .audio:
                "Preparing your recording."
            case .text:
                "Preparing your text import."
            case .pdf:
                "Preparing your PDF import."
            case .youtube:
                "Preparing your YouTube import."
            }
        case .uploading:
            switch lecture.sourceType {
            case .audio:
                "Uploading your recording."
            case .text:
                "Saving your text for processing."
            case .pdf:
                "Saving your PDF for processing."
            case .youtube:
                "Checking your YouTube video."
            }
        case .transcribing:
            switch lecture.sourceType {
            case .audio:
                "Converting your speech to text. This may take a moment."
            case .text:
                "Preparing your text for note generation."
            case .pdf:
                "Extracting text from your PDF for note generation."
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
            case .pdf:
                "We couldn't finish processing this PDF import."
            case .youtube:
                "We couldn't finish processing this YouTube video."
            }
        }
    }

    private var headlineTitle: LocalizedStringResource {
        switch lecture.status {
        case .failed:
            lecture.sourceType == .audio ? "Transcription Failed" : "Processing Failed"
        case .ready:
            switch lecture.sourceType {
            case .audio:
                "Your Recording Is Ready"
            case .text:
                "Your Text Import Is Ready"
            case .pdf:
                "Your PDF Import Is Ready"
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

    private var footerMessage: FooterMessage {
        switch lecture.status {
        case .uploading:
            switch lecture.sourceType {
            case .audio:
                .localized("Uploading your recording so processing can begin.")
            case .text:
                .localized("Saving your text so processing can begin.")
            case .pdf:
                .localized("Extracting text from your PDF so processing can begin.")
            case .youtube:
                .localized("Saving your YouTube source so processing can begin.")
            }
        case .transcribing:
            switch lecture.sourceType {
            case .audio:
                .localized("Listening for the important concepts and turning them into text.")
            case .text:
                .localized("Reviewing the imported text before creating study materials.")
            case .pdf:
                .localized("Reviewing the imported PDF text before creating study materials.")
            case .youtube:
                .localized("Trying to convert YouTube captions into transcript text for your study materials.")
            }
        case .generating:
            .localized("Transforming the transcript into a polished study note.")
        case .ready:
            .localized("You can now open the summary, transcript, flashcards, and quiz.")
        case .failed:
            .custom(lecture.processingErrorMessage ?? String(localized: "Processing failed."))
        case .draft:
            .localized("Getting everything ready.")
        }
    }

    @ViewBuilder
    private var footerMessageView: some View {
        switch footerMessage {
        case .localized(let message):
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        case .custom(let message):
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
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

private enum FooterMessage {
    case localized(LocalizedStringResource)
    case custom(String)
}

private struct ProcessingHeroView: View {
    let title: LocalizedStringResource
    let message: LocalizedStringResource
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
                    .tint(AppColor.ink)
                    .scaleEffect(1.65)
                    .padding(.top, 8)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3)
                    .bold()
                    .multilineTextAlignment(.center)

                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppColor.fillSubtle)

                        Capsule()
                            .fill(AppColor.ink)
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
