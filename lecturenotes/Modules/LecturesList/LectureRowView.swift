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
                        lectureTitleView
                        metadata
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

    @ViewBuilder
    private var lectureTitleView: some View {
        if let localizedDisplayTitleKey = lecture.localizedDisplayTitleKey {
            Text(localizedDisplayTitleKey.resource)
                .bold()
                .lineLimit(1)
        } else {
            Text(lecture.title)
                .bold()
                .lineLimit(1)
        }
    }

    private var metadata: Text {
        switch lecture.sourceType {
        case .audio:
            Text(lecture.createdAt, format: LectureFormatters.dayMonthYear)
            + Text(" • ")
            + Text(LectureFormatters.clockText(lecture.duration))
        case .text, .pdf, .youtube:
            Text(lecture.createdAt, format: LectureFormatters.dayMonthYear)
            + Text(" • ")
            + Text(lecture.sourceType.titleResource)
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
