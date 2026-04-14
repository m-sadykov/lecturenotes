import ActivityKit
import SwiftUI
import WidgetKit

struct RecordingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingLiveActivityAttributes.self) { context in
            RecordingLiveActivityView(context: context)
                .widgetURL(RecordingLiveActivityRoute.url(for: .show))
                .activityBackgroundTint(.white.opacity(0.18))
                .activitySystemActionForegroundColor(.black.opacity(0.85))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    DynamicIslandWaveformView(phase: context.state.phase, size: .expanded)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    DynamicIslandExpandedTrailingView(state: context.state)
                }
            } compactLeading: {
                DynamicIslandWaveformView(phase: context.state.phase, size: .compact)
            } compactTrailing: {
                CompactDynamicIslandTimerView(state: context.state)
            } minimal: {
                DynamicIslandWaveformView(phase: context.state.phase, size: .minimal)
            }
            .widgetURL(RecordingLiveActivityRoute.url(for: .show))
            .keylineTint(statusColor(for: context.state.phase))
        }
    }

    private func statusColor(for phase: RecordingLiveActivityPhase) -> Color {
        switch phase {
        case .recording:
            dynamicIslandAccentColor(for: phase)
        case .paused:
            .orange
        case .finishing:
            .green
        }
    }
}

private func dynamicIslandAccentColor(for phase: RecordingLiveActivityPhase) -> Color {
    switch phase {
    case .recording:
        Color(red: 1, green: 0.39, blue: 0.42)
    case .paused:
        .orange
    case .finishing:
        .green
    }
}

private struct DynamicIslandWaveformView: View {
    enum Size {
        case expanded
        case compact
        case minimal

        var barWidth: CGFloat {
            switch self {
            case .expanded:
                4
            case .compact:
                2.5
            case .minimal:
                2
            }
        }

        var spacing: CGFloat {
            switch self {
            case .expanded:
                3
            case .compact:
                1.8
            case .minimal:
                1.3
            }
        }

        var heights: [CGFloat] {
            switch self {
            case .expanded:
                [6, 10, 18, 28, 40, 28, 18, 10, 6]
            case .compact:
                [4, 7, 10, 14, 10, 7, 4]
            case .minimal:
                [4, 7, 10, 7, 4]
            }
        }
    }

    let phase: RecordingLiveActivityPhase
    let size: Size

    var body: some View {
        switch phase {
        case .recording:
            HStack(alignment: .center, spacing: size.spacing) {
                ForEach(Array(size.heights.enumerated()), id: \.offset) { index, height in
                    Capsule()
                        .fill(dynamicIslandAccentColor(for: phase).opacity(barOpacity(for: index)))
                        .frame(width: size.barWidth, height: height)
                }
            }
        case .paused:
            Image(systemName: "pause.fill")
                .font(.system(size: pauseFontSize, weight: .bold))
                .foregroundStyle(dynamicIslandAccentColor(for: phase))
        case .finishing:
            Image(systemName: "checkmark")
                .font(.system(size: pauseFontSize, weight: .bold))
                .foregroundStyle(dynamicIslandAccentColor(for: phase))
        }
    }

    private var pauseFontSize: CGFloat {
        switch size {
        case .expanded:
            14
        case .compact:
            11
        case .minimal:
            10
        }
    }

    private func barOpacity(for index: Int) -> Double {
        let centerIndex = Double(size.heights.count - 1) / 2
        let distance = abs(Double(index) - centerIndex)
        return max(0.45, 1 - (distance * 0.12))
    }
}

private struct CompactDynamicIslandTimerView: View {
    let state: RecordingLiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 6) {
            CompactDynamicIslandIndicator(phase: state.phase)

            compactTimerText(for: state)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(dynamicIslandAccentColor(for: state.phase))
        }
    }
}

private struct CompactDynamicIslandIndicator: View {
    let phase: RecordingLiveActivityPhase

    var body: some View {
        switch phase {
        case .recording:
            Circle()
                .fill(dynamicIslandAccentColor(for: phase))
                .frame(width: 5, height: 5)
        case .paused:
            Image(systemName: "pause.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(dynamicIslandAccentColor(for: phase))
        case .finishing:
            Image(systemName: "checkmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(dynamicIslandAccentColor(for: phase))
        }
    }
}

private struct DynamicIslandExpandedTrailingView: View {
    let state: RecordingLiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            compactTimerText(for: state)
                .font(.title2.monospacedDigit())
                .foregroundStyle(dynamicIslandAccentColor(for: state.phase))

            if state.phase == .finishing {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            } else {
                Link(destination: RecordingLiveActivityRoute.url(for: .finish)) {
                    DynamicIslandStopButton()
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct DynamicIslandStopButton: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(.white, lineWidth: 3)
                .frame(width: 38, height: 38)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(dynamicIslandAccentColor(for: .recording))
                .frame(width: 18, height: 18)
        }
    }
}

private struct RecordingLiveActivityView: View {
    let context: ActivityViewContext<RecordingLiveActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: context.state.phase.systemImageName)
                    .foregroundStyle(statusColor)

                Text("LectraAI")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.primary)

                Spacer()

                Link(destination: RecordingLiveActivityRoute.url(for: .finish)) {
                    Text("Finish")
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.08))
                        .clipShape(.capsule)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                timerText(for: context.state)
                    .font(.largeTitle.monospacedDigit())
                    .bold()
                    .foregroundStyle(.primary)

                Text("/ \(formattedClock(context.state.limitSeconds))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                Text(context.state.phase.statusText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                if context.state.phase == .recording {
                    Text(context.state.phase.detailText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusColor: Color {
        switch context.state.phase {
        case .recording:
            Color(red: 0.89, green: 0.29, blue: 0.27)
        case .paused:
            .orange
        case .finishing:
            .green
        }
    }
}

private func timerText(for state: RecordingLiveActivityAttributes.ContentState) -> Text {
    switch state.phase {
    case .recording:
        Text(state.timerStartDate, style: .timer)
    case .paused, .finishing:
        Text(verbatim: formattedClock(state.elapsedSeconds))
    }
}

private func compactTimerText(for state: RecordingLiveActivityAttributes.ContentState) -> Text {
    switch state.phase {
    case .recording:
        Text(state.timerStartDate, style: .timer)
    case .paused, .finishing:
        Text(verbatim: formattedClock(state.elapsedSeconds))
    }
}

private func formattedClock(_ totalSeconds: Int) -> String {
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60

    if hours > 0 {
        return "\(hours):\(twoDigit(minutes)):\(twoDigit(seconds))"
    } else {
        return "\(minutes):\(twoDigit(seconds))"
    }
}

private func twoDigit(_ value: Int) -> String {
    if value >= 10 {
        "\(value)"
    } else {
        "0\(value)"
    }
}
