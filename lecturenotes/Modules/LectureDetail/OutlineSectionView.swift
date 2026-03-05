import SwiftUI

struct OutlineSectionView: View {
    let lecture: Lecture

    var body: some View {
        List {
            if lecture.outline.isEmpty {
                Text("Outline is not available yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(lecture.outline, id: \.self) { item in
                    Text(item)
                }
            }
        }
    }
}
