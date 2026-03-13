import SwiftUI

struct LectureRowView: View {
    let lecture: Lecture
    let onOpen: () -> Void
    let onMore: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center) {
                Button(action: onOpen) {
                    HStack(alignment: .center) {
                        Image(systemName: "play.fill")
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

                Button("Actions", systemImage: "ellipsis") {
                    onMore()
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.white)
        .clipShape(.rect(cornerRadius: 20))
    }

    private var metadata: String {
        "\(lecture.createdAt.formatted(LectureFormatters.dayMonthYear)) • \(LectureFormatters.clockText(lecture.duration))"
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
