import SwiftUI

/// Audio player card: scrubber, ±10 s skip, play/pause, speed and share.
struct LectureAudioPlayerView: View {
    let lecture: Lecture
    @Bindable var viewModel: LecturePlayerViewModel

    private static let skipInterval: Duration = .seconds(10)

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                PlayerProgressBarView(
                    progress: Binding(
                        get: { viewModel.progress },
                        set: { viewModel.seek(to: $0) }
                    ),
                    isEnabled: viewModel.canPlay
                )

                HStack {
                    Text(LectureFormatters.clockText(viewModel.currentTime))
                    Spacer()
                    Text(LectureFormatters.clockText(viewModel.totalDuration))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }

            HStack {
                LectureAudioShareButton(lecture: lecture)
                    .frame(maxWidth: .infinity)

                Button("Back 10 seconds", systemImage: "gobackward.10") {
                    viewModel.seek(by: .zero - Self.skipInterval)
                }
                .frame(maxWidth: .infinity)

                LecturePlayPauseButton(
                    isPlaying: viewModel.isPlaying,
                    action: viewModel.togglePlayback
                )
                .frame(maxWidth: .infinity)

                Button("Forward 10 seconds", systemImage: "goforward.10") {
                    viewModel.seek(by: Self.skipInterval)
                }
                .frame(maxWidth: .infinity)

                Button(action: viewModel.cyclePlaybackRate) {
                    Text(rateText)
                        .font(.headline.monospacedDigit())
                }
                .accessibilityLabel(Text("Playback speed"))
                .accessibilityValue(Text(rateText))
                .frame(maxWidth: .infinity)
            }
            .labelStyle(.iconOnly)
            .font(.title2)
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .disabled(!viewModel.canPlay)
        }
        .padding()
        .background(AppColor.surface)
        .clipShape(.rect(cornerRadius: 20))
    }

    private var rateText: String {
        if viewModel.playbackRate == floor(viewModel.playbackRate) {
            "\(Int(viewModel.playbackRate))x"
        } else {
            "\(viewModel.playbackRate.formatted(.number.precision(.fractionLength(0...2))))x"
        }
    }
}

/// The player's main action: a filled `ink` circle, like the record button on the home
/// screen, so the card itself can stay white while play/pause still stands out.
private struct LecturePlayPauseButton: View {
    let isPlaying: Bool
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @ScaledMetric(relativeTo: .title2) private var diameter: CGFloat = 56

    var body: some View {
        Button(
            isPlaying ? "Pause" : "Play",
            systemImage: isPlaying ? "pause.fill" : "play.fill",
            action: action
        )
        .labelStyle(.iconOnly)
        .font(.title2)
        .contentTransition(.symbolEffect(.replace))
        .foregroundStyle(AppColor.onInk)
        .frame(width: diameter, height: diameter)
        .background(AppColor.ink, in: .circle)
        .contentShape(.circle)
        .opacity(isEnabled ? 1 : 0.35)
    }
}

/// Shares the recording, from the device or downloaded from the cloud on demand.
/// Keeps its slot (hidden) only when the lecture has no audio at all, so the play
/// button stays centered.
private struct LectureAudioShareButton: View {
    let lecture: Lecture

    var body: some View {
        if let item = LectureAudioShareItem(lecture: lecture) {
            ShareLink(item: item, preview: SharePreview(lecture.displayTitle)) {
                Label("Share Audio", systemImage: "square.and.arrow.up")
            }
        } else {
            Label("Share Audio", systemImage: "square.and.arrow.up")
                .hidden()
                .accessibilityHidden(true)
        }
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
                    .fill(AppColor.accent.opacity(0.18))
                    .frame(height: 6)

                Capsule()
                    .fill(AppColor.accent)
                    .frame(width: max(thumbOffset, 6), height: 6)

                Circle()
                    .fill(AppColor.accent)
                    .frame(width: 18, height: 18)
                    .shadow(color: AppColor.shadow, radius: 8, y: 2)
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
        .accessibilityElement()
        .accessibilityLabel(Text("Playback position"))
        .accessibilityValue(Text(progress.clamped(to: 0...1), format: .percent.precision(.fractionLength(0))))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                progress = (progress + 0.05).clamped(to: 0...1)
            case .decrement:
                progress = (progress - 0.05).clamped(to: 0...1)
            @unknown default:
                break
            }
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    ZStack {
        AppColor.canvas.ignoresSafeArea()

        LectureAudioPlayerView(
            lecture: previewLectureForPlayer,
            viewModel: LecturePlayerViewModel(
                lectureTitle: previewLectureForPlayer.displayTitle,
                audioURL: nil,
                remoteAudioPath: nil,
                fallbackDuration: .seconds(600)
            )
        )
        .padding()
    }
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
