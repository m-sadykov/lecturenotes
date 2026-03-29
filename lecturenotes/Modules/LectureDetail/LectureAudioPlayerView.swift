import SwiftUI

struct LectureAudioPlayerView: View {
    let lecture: Lecture
    @Bindable var viewModel: LecturePlayerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                lectureTitleView

                metadataText
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 14) {
                Button(action: viewModel.togglePlayback) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(.primary)
                        .frame(width: 52, height: 52)
                        .background(Color.black.opacity(0.08))
                        .clipShape(.circle)
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canPlay)

                VStack(spacing: 8) {
                    PlayerProgressBarView(
                        progress: Binding(
                            get: { viewModel.progress },
                            set: { viewModel.seek(to: $0) }
                        ),
                        isEnabled: viewModel.canPlay
                    )

                    HStack {
                        Text(LectureFormatters.clockText(viewModel.currentTime))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(LectureFormatters.clockText(viewModel.totalDuration))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 14)

                Button(action: viewModel.cyclePlaybackRate) {
                    Text(rateText)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .frame(minWidth: 36)
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canPlay)
                .padding(.top, 18)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
    }

    private var rateText: String {
        if viewModel.playbackRate == floor(viewModel.playbackRate) {
            "\(Int(viewModel.playbackRate))x"
        } else {
            "\(viewModel.playbackRate.formatted(.number.precision(.fractionLength(2))))x"
        }
    }

    @ViewBuilder
    private var lectureTitleView: some View {
        if let localizedDisplayTitleKey = lecture.localizedDisplayTitleKey {
            Text(localizedDisplayTitleKey.resource)
                .font(.title)
                .bold()
                .lineLimit(2)
        } else {
            Text(lecture.title)
                .font(.title)
                .bold()
                .lineLimit(2)
        }
    }

    private var metadataText: Text {
        Text(lecture.createdAt, format: LectureFormatters.date)
        + Text(" · ")
        + Text(LectureFormatters.clockText(lecture.duration))
        + Text(" · ")
        + Text(lecture.sourceType.titleResource)
    }
}

private struct PlayerProgressBarView: View {
    @Binding var progress: Double

    let isEnabled: Bool

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let clampedProgress = progress.clamped(to: 0...1)
            let thumbOffset = width * clampedProgress

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.black.opacity(0.08))
                    .frame(height: 6)

                Capsule()
                    .fill(.black)
                    .frame(width: max(thumbOffset, 6), height: 6)

                Circle()
                    .fill(.black)
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                    .offset(x: min(max(thumbOffset - 9, 0), width - 18))
            }
            .frame(height: 24)
            .animation(.linear(duration: 0.08), value: clampedProgress)
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEnabled else {
                            return
                        }

                        progress = (value.location.x / width).clamped(to: 0...1)
                    }
                    .onEnded { value in
                        guard isEnabled else {
                            return
                        }

                        progress = (value.location.x / width).clamped(to: 0...1)
                    }
            )
        }
        .frame(height: 24)
        .allowsHitTesting(isEnabled)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    LectureAudioPlayerView(
        lecture: previewLectureForPlayer,
        viewModel: LecturePlayerViewModel(
            audioURL: nil,
            fallbackDuration: .seconds(600)
        )
    )
    .padding()
}

private let previewLectureForPlayer = Lecture(
    title: "New Recording",
    sourceType: .audio,
    createdAt: Date(timeIntervalSinceReferenceDate: 794_855_467),
    duration: .seconds(32),
    status: .ready,
    transcript: "",
    summaryShort: "",
    summaryLong: "",
    flashcards: [],
    quiz: []
)
