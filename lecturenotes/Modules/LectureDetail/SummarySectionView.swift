import SwiftUI

struct SummarySectionView: View {
    let lecture: Lecture

    var body: some View {
        ScrollView {
            Group {
                if lecture.summaryLong.isEmpty {
                    Text("No detailed summary yet.")
                } else {
                    Text(lecture.summaryLong)
                }
            }
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .textSelection(.enabled)
        }
    }
}
