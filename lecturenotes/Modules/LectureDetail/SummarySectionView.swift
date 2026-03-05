import SwiftUI

struct SummarySectionView: View {
    let lecture: Lecture

    var body: some View {
        List {
            Section("Short") {
                Text(lecture.summaryShort.isEmpty ? "No summary yet." : lecture.summaryShort)
            }
            Section("Detailed") {
                Text(lecture.summaryLong.isEmpty ? "No detailed summary yet." : lecture.summaryLong)
            }
        }
    }
}
