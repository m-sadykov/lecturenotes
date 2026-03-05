import SwiftUI

struct LectureDetailView: View {
    let lecture: Lecture

    var body: some View {
        TabView {
            Tab("Summary", systemImage: "text.book.closed") {
                SummarySectionView(lecture: lecture)
            }
            Tab("Outline", systemImage: "list.bullet.rectangle") {
                OutlineSectionView(lecture: lecture)
            }
            Tab("Glossary", systemImage: "character.book.closed") {
                GlossarySectionView(lecture: lecture)
            }
            Tab("Flashcards", systemImage: "rectangle.on.rectangle") {
                FlashcardsSectionView(lecture: lecture)
            }
            Tab("Quiz", systemImage: "checklist") {
                QuizSectionView(lecture: lecture)
            }
            Tab("Transcript", systemImage: "text.alignleft") {
                TranscriptSectionView(lecture: lecture)
            }
        }
        .navigationTitle(lecture.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        if let lecture = MockLectures.makeLectures().first {
            LectureDetailView(lecture: lecture)
        }
    }
}
