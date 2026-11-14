import SwiftUI

/// The last line of a lecture row: processing progress, a failure note, or the summary preview.
struct LectureRowStatusView: View {
    let status: LectureRowStatus
    let previewText: String

    var body: some View {
        switch status {
        case .processing(let lectureStatus):
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.mini)
                Text(lectureStatus.titleResource)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        case .failed:
            Label("Failed", systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.red)
        case .none:
            if !previewText.isEmpty {
                Text(previewText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
