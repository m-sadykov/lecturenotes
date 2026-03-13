import SwiftUI

struct LectureDetailView: View {
    let lecture: Lecture
    @State private var playerViewModel: LecturePlayerViewModel?
    @State private var selectedSection: LectureDetailSection = .summary
    @State private var activeDestination: LectureDetailDestination?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 18) {
                if let playerViewModel {
                    LectureAudioPlayerView(lecture: lecture, viewModel: playerViewModel)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            LectureDetailSectionChipsView(
                selectedSection: $selectedSection,
                onSelectSection: { section in
                    switch section {
                    case .flashcards:
                        activeDestination = .flashcards
                    default:
                        selectedSection = section
                    }
                }
            )
                .padding(.top, 16)
                .padding(.bottom, 8)

            LectureDetailSectionContentView(
                lecture: lecture,
                selectedSection: selectedSection
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            guard playerViewModel == nil else {
                return
            }

            playerViewModel = LecturePlayerViewModel(
                audioURL: lecture.audioURL,
                fallbackDuration: lecture.duration
            )
        }
        .onDisappear {
            playerViewModel?.cleanup()
        }
        .navigationDestination(item: $activeDestination) { destination in
            switch destination {
            case .flashcards:
                FlashcardsPracticeView(viewModel: FlashcardsPracticeViewModel(cards: lecture.flashcards))
            }
        }
    }
}

#Preview {
    NavigationStack {
        if let lecture = previewLecture {
            LectureDetailView(lecture: lecture)
        }
    }
}

private let previewLecture: Lecture? = {
    guard var lecture = MockLectures.makeLectures().first else {
        return nil
    }

    lecture.audioURL = nil
    return lecture
}()

private enum LectureDetailSection: String, CaseIterable, Identifiable {
    case summary = "Summary"
    case transcript = "Transcript"
    case flashcards = "Flashcards"
    case quiz = "Quiz"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .summary:
            "📝"
        case .transcript:
            "📄"
        case .flashcards:
            "🔄"
        case .quiz:
            "⁉️"
        }
    }
}

private enum LectureDetailDestination: Identifiable {
    case flashcards

    var id: String {
        switch self {
        case .flashcards:
            "flashcards"
        }
    }
}

private struct LectureDetailSectionChipsView: View {
    @Binding var selectedSection: LectureDetailSection
    let onSelectSection: (LectureDetailSection) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(LectureDetailSection.allCases) { section in
                    LectureDetailSectionChip(
                        title: section.rawValue,
                        emoji: section.emoji,
                        isSelected: selectedSection == section
                    ) {
                        onSelectSection(section)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
    }
}

private struct LectureDetailSectionChip: View {
    let title: String
    let emoji: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Text(emoji)
                    .font(.title2)

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            .frame(width: 108, height: 88)
            .background(.black.opacity(0.05))
            .clipShape(.rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.black.opacity(0.10) : Color.black.opacity(0.03), lineWidth: 1)
            }
            .shadow(color: .black.opacity(isSelected ? 0.07 : 0.04), radius: isSelected ? 14 : 12, y: 4)
        }
        .buttonStyle(.plain)
    }
}

private struct LectureDetailSectionContentView: View {
    let lecture: Lecture
    let selectedSection: LectureDetailSection

    var body: some View {
        Group {
            switch selectedSection {
            case .summary:
                SummarySectionView(lecture: lecture)
            case .transcript:
                TranscriptSectionView(lecture: lecture)
            case .flashcards:
                SummarySectionView(lecture: lecture)
            case .quiz:
                QuizSectionView(lecture: lecture)
            }
        }
    }
}
