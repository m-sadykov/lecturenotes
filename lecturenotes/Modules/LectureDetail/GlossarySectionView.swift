import SwiftUI

struct GlossarySectionView: View {
    let lecture: Lecture

    var body: some View {
        List {
            if lecture.glossary.isEmpty {
                Text("Glossary is not available yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(lecture.glossary) { item in
                    VStack(alignment: .leading) {
                        Text(item.term)
                            .bold()
                        Text(item.definition)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
