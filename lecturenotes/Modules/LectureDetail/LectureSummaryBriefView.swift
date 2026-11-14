import SwiftUI

/// One- or two-sentence "In short" callout shown above the full study note.
struct LectureSummaryBriefView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("In Short", systemImage: "sparkles")
                .font(.subheadline.bold())
                .foregroundStyle(AppColor.accent)

            Text(text)
                .font(.body)
                .lineSpacing(3)
                .textSelection(.enabled)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface)
        .clipShape(.rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    LectureSummaryBriefView(
        text: "Lewis's work seeks to awaken readers to a reality deeper than ordinary consciousness."
    )
    .padding()
}
