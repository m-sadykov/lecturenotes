import SwiftUI

struct LectureRowView: View {
    let lecture: Lecture
    let onOpen: () -> Void
    let onMore: () -> Void
    
    @State private var menuTapFeedbackTrigger = 0

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onOpen) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: iconName)
                        .frame(width: 40, height: 40)
                        .foregroundStyle(.secondary)
                        .background(.primary.opacity(0.05), in: .circle)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(lecture.title)
                            .bold()
                            .lineLimit(1)
                        Text(metadata)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if !previewText.isEmpty {
                            Text(previewText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            Button {
                menuTapFeedbackTrigger += 1
                onMore()
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 14)
        .sensoryFeedback(.impact(weight: .light), trigger: menuTapFeedbackTrigger)
    }

    private var metadata: String {
        switch lecture.sourceType {
        case .audio:
            "\(lecture.createdAt.formatted(LectureFormatters.dayMonthYear)) • \(LectureFormatters.clockText(lecture.duration))"
        case .text, .pdf, .youtube:
            "\(lecture.createdAt.formatted(LectureFormatters.dayMonthYear)) • \(lecture.sourceType.title)"
        }
    }

    private var iconName: String {
        switch lecture.sourceType {
        case .audio:
            "waveform"
        case .text:
            "doc.text"
        case .pdf:
            "doc.richtext"
        case .youtube:
            "play.rectangle"
        }
    }

    private var previewText: String {
        if !lecture.summaryShort.isEmpty {
            return lecture.summaryShort
        }
        if !lecture.transcript.isEmpty {
            return lecture.transcript
        }
        return ""
    }
}
