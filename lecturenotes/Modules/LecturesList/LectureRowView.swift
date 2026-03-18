import SwiftUI

struct LectureRowView: View {
    let lecture: Lecture
    let onOpen: () -> Void
    let onMore: () -> Void
    
    @State private var menuTapFeedbackTrigger = 0

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center) {
                Button(action: onOpen) {
                    HStack(alignment: .center) {
                        Image(systemName: iconName)
                            .frame(width: 42, height: 42)
                            .background(.black.opacity(0.06))
                            .clipShape(.circle)

                        VStack(alignment: .leading) {
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

                        Spacer()
                    }
                }
                .buttonStyle(.plain)

                Button {
                    menuTapFeedbackTrigger += 1
                    onMore()
                } label: {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.white)
        .clipShape(.rect(cornerRadius: 20))
        .sensoryFeedback(.impact(weight: .light), trigger: menuTapFeedbackTrigger)
    }

    private var metadata: String {
        switch lecture.sourceType {
        case .audio:
            "\(lecture.createdAt.formatted(LectureFormatters.dayMonthYear)) • \(LectureFormatters.clockText(lecture.duration))"
        case .text, .youtube:
            "\(lecture.createdAt.formatted(LectureFormatters.dayMonthYear)) • \(lecture.sourceType.title)"
        }
    }

    private var iconName: String {
        switch lecture.sourceType {
        case .audio:
            "waveform"
        case .text:
            "doc.text"
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
