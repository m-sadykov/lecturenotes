import Foundation

protocol LectureRepository {
    func start() async
    func observeChanges() -> AsyncStream<Void>
    func fetchLectures() async -> [Lecture]
    func searchLectures(matching query: String) async -> [Lecture]
    func fetchFolders() async -> [LectureFolder]
    func fetchLecture(id: UUID) async -> Lecture?
    func saveLecture(_ lecture: Lecture) async throws
    func saveFolders(_ folders: [LectureFolder]) async throws
    func deleteLecture(id: UUID) async throws
}

extension LectureRepository {
    func start() async {}

    func observeChanges() -> AsyncStream<Void> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    func searchLectures(matching query: String) async -> [Lecture] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let lectures = await fetchLectures()

        guard !trimmedQuery.isEmpty else {
            return lectures
        }

        return lectures.filter { $0.matchesSearchQuery(trimmedQuery) }
    }
}

struct MockLectureRepository: LectureRepository {
    private let folders: [LectureFolder]
    private let lectures: [Lecture]

    init(
        folders: [LectureFolder] = MockLectures.makeFolders(),
        lectures: [Lecture]? = nil
    ) {
        self.folders = folders
        self.lectures = lectures ?? MockLectures.makeLectures(folders: folders)
    }

    func fetchLectures() async -> [Lecture] {
        lectures.sorted { $0.createdAt > $1.createdAt }
    }

    func fetchFolders() async -> [LectureFolder] {
        folders
    }

    func fetchLecture(id: UUID) async -> Lecture? {
        lectures.first(where: { $0.id == id })
    }

    func saveLecture(_ lecture: Lecture) async throws {}

    func saveFolders(_ folders: [LectureFolder]) async throws {}

    func deleteLecture(id: UUID) async throws {}
}

enum MockLectures {
    private static let folder1ID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private static let folder2ID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private static let folder3ID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

    private static let lecture1ID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private static let lecture2ID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private static let lecture3ID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!

    private static let flashcard1ID = UUID(uuidString: "E1111111-1111-1111-1111-111111111111")!
    private static let flashcard2ID = UUID(uuidString: "E2222222-2222-2222-2222-222222222222")!
    private static let quiz1ID = UUID(uuidString: "F1111111-1111-1111-1111-111111111111")!
    private static let quiz2ID = UUID(uuidString: "F2222222-2222-2222-2222-222222222222")!

    private static let lecture1Date = Date(timeIntervalSinceReferenceDate: 794_855_467)
    private static let lecture2Date = Date(timeIntervalSinceReferenceDate: 794_772_667)
    private static let lecture3Date = Date(timeIntervalSinceReferenceDate: 794_687_067)

    static func makeFolders() -> [LectureFolder] {
        [
            LectureFolder(id: folder1ID, name: "Folder 1"),
            LectureFolder(id: folder2ID, name: "Folder 2"),
            LectureFolder(id: folder3ID, name: "Folder 3")
        ]
    }

    static func makeLectures() -> [Lecture] {
        let folders = makeFolders()
        return makeLectures(folders: folders)
    }

    static func makeLectures(folders: [LectureFolder]) -> [Lecture] {
        return [
            Lecture(
                id: lecture1ID,
                title: "Plant Physiology Basics",
                sourceType: .audio,
                audioURL: nil,
                sourceURL: nil,
                folderID: nil,
                createdAt: lecture1Date,
                duration: .seconds(2_440),
                status: .ready,
                transcript: "Today we covered photosynthesis, chloroplasts, and ATP synthesis in plants.",
                summaryShort: "Lecture introduced photosynthesis and how plants convert sunlight into energy.",
                summaryLong: "We explored photosynthesis stages, light-dependent reactions, ATP production, and practical examples about plant metabolism.",
                flashcards: [
                    Flashcard(id: flashcard1ID, question: "What is photosynthesis?", answer: "A process where plants convert light into chemical energy."),
                    Flashcard(id: flashcard2ID, question: "Where does photosynthesis occur?", answer: "In chloroplasts.")
                ],
                quiz: [
                    QuizQuestion(id: quiz1ID, question: "Which pigment absorbs sunlight?", options: ["Chlorophyll", "Keratin", "Hemoglobin", "Melanin"], correctIndex: 0),
                    QuizQuestion(id: quiz2ID, question: "Main product of light reaction?", options: ["ATP", "Insulin", "DNA", "Collagen"], correctIndex: 0)
                ]
            ),
            Lecture(
                id: lecture2ID,
                title: "Thermodynamics Intro",
                sourceType: .text,
                audioURL: nil,
                sourceURL: nil,
                folderID: nil,
                createdAt: lecture2Date,
                duration: .seconds(1_860),
                status: .generating,
                transcript: "The lecture compared closed and open systems, internal energy, and the first law of thermodynamics.",
                summaryShort: "",
                summaryLong: "",
                flashcards: [],
                quiz: []
            ),
            Lecture(
                id: lecture3ID,
                title: "Linear Algebra: Matrices",
                sourceType: .audio,
                audioURL: nil,
                sourceURL: nil,
                folderID: nil,
                createdAt: lecture3Date,
                duration: .seconds(3_000),
                status: .failed,
                transcript: "",
                summaryShort: "",
                summaryLong: "",
                flashcards: [],
                quiz: []
            )
        ]
    }
}
