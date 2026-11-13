import SwiftUI

/// Full transcript split into readable paragraphs.
struct LectureTranscriptScreen: View {
    let transcript: String
    let onCopy: () -> Void

    @State private var paragraphs: [String] = []

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(paragraphs.indices, id: \.self) { index in
                    Text(paragraphs[index])
                        .font(.body)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .textSelection(.enabled)
            .padding()
        }
        .background(AppColor.canvas)
        .navigationTitle(Text(LectureDetailContent.transcript.titleResource))
        .navigationBarTitleDisplayMode(.inline)
        .circleBackButton()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ToolbarCircleButton("Copy", systemImage: "doc.on.doc", action: onCopy)
            }
            .hiddenSharedBackground()
        }
        .task(id: transcript) {
            paragraphs = TranscriptParagraphFormatter.paragraphs(from: transcript)
        }
    }
}
