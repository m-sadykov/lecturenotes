import SwiftUI

/// Card shown in place of the audio player for YouTube imports: opens the source video
/// in the YouTube app or in Safari.
struct LectureYouTubeLinkView: View {
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                Image(systemName: "play.rectangle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)

                Text("Watch on YouTube")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right")
                    .font(.subheadline.bold())
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.surface)
            .clipShape(.rect(cornerRadius: 20))
            .contentShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        AppColor.canvas.ignoresSafeArea()

        if let url = URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ") {
            LectureYouTubeLinkView(url: url)
                .padding()
        }
    }
}
