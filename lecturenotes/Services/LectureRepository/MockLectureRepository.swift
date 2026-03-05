import Foundation

protocol LectureRepository {
    func fetchLectures() async -> [Lecture]
    func fetchLecture(id: UUID) async -> Lecture?
}

struct MockLectureRepository: LectureRepository {
    private let lectures: [Lecture]

    init(lectures: [Lecture] = MockLectures.makeLectures()) {
        self.lectures = lectures
    }

    func fetchLectures() async -> [Lecture] {
        lectures.sorted { $0.createdAt > $1.createdAt }
    }

    func fetchLecture(id: UUID) async -> Lecture? {
        lectures.first(where: { $0.id == id })
    }
}

enum MockLectures {
    static func makeLectures() -> [Lecture] {
        [
            Lecture(
                title: "Plant Physiology Basics",
                course: "Biology 101",
                createdAt: .now.addingTimeInterval(-3_600),
                duration: .seconds(2_440),
                status: .ready,
                transcript: "Today we covered photosynthesis, chloroplasts, and ATP synthesis in plants.",
                summaryShort: "Lecture introduced photosynthesis and how plants convert sunlight into energy.",
                summaryLong: "We explored photosynthesis stages, light-dependent reactions, ATP production, and practical examples about plant metabolism.",
                outline: ["Introduction", "Photosynthesis Stages", "Cell Structures", "Key Takeaways"],
                glossary: [
                    GlossaryItem(term: "Photosynthesis", definition: "Conversion of light into chemical energy."),
                    GlossaryItem(term: "Chlorophyll", definition: "Pigment responsible for light absorption.")
                ],
                flashcards: [
                    Flashcard(question: "What is photosynthesis?", answer: "A process where plants convert light into chemical energy."),
                    Flashcard(question: "Where does photosynthesis occur?", answer: "In chloroplasts.")
                ],
                quiz: [
                    QuizQuestion(question: "Which pigment absorbs sunlight?", options: ["Chlorophyll", "Keratin", "Hemoglobin", "Melanin"], correctIndex: 0),
                    QuizQuestion(question: "Main product of light reaction?", options: ["ATP", "Insulin", "DNA", "Collagen"], correctIndex: 0)
                ]
            ),
            Lecture(
                title: "Thermodynamics Intro",
                course: "Physics",
                createdAt: .now.addingTimeInterval(-86_400),
                duration: .seconds(1_860),
                status: .generating,
                transcript: "",
                summaryShort: "",
                summaryLong: "",
                outline: [],
                glossary: [],
                flashcards: [],
                quiz: []
            ),
            Lecture(
                title: "Linear Algebra: Matrices",
                course: "Math",
                createdAt: .now.addingTimeInterval(-170_000),
                duration: .seconds(3_000),
                status: .failed,
                transcript: "",
                summaryShort: "",
                summaryLong: "",
                outline: [],
                glossary: [],
                flashcards: [],
                quiz: []
            )
        ]
    }
}
