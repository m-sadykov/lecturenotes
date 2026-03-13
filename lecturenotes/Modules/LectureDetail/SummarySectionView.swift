import SwiftUI

struct SummarySectionView: View {
    let lecture: Lecture

    var body: some View {
        ScrollView {
            Text(lecture.summaryLong.isEmpty ? "No detailed summary yet." : lecture.summaryLong)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .textSelection(.enabled)
        }
    }
}
