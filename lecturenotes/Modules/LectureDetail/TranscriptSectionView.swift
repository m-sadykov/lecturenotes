import SwiftUI

struct TranscriptSectionView: View {
    let lecture: Lecture

    var body: some View {
        ScrollView {
            Text(lecture.transcript.isEmpty ? "Transcript is not available yet." : lecture.transcript)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
    }
}
