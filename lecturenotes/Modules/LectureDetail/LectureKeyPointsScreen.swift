import SwiftUI

/// The lecture's key takeaways, rendered from Markdown.
struct LectureKeyPointsScreen: View {
    let keyPoints: String
    let onCopy: () -> Void

    var body: some View {
        ScrollView {
            MarkdownContentView(markdown: keyPoints)
                .padding()
        }
        .background(AppColor.canvas)
        .navigationTitle(Text(LectureDetailContent.keyPoints.titleResource))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Copy", systemImage: "doc.on.doc", action: onCopy)
            }
        }
    }
}
