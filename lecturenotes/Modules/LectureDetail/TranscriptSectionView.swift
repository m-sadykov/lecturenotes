import SwiftUI

struct TranscriptSectionView: View {
    let lecture: Lecture

    var body: some View {
        ScrollView {
            Group {
                if lecture.transcript.isEmpty {
                    Text("Transcript is not available yet.")
                } else {
                    Text(lecture.transcript)
                }
            }
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }
}
