import FirebaseFirestore
import Foundation

enum FirestoreLectureMapper {
    static func documentData(for lecture: Lecture) -> [String: Any] {
        var data: [String: Any] = [
            "id": lecture.id.uuidString,
            "title": lecture.title,
            "sourceType": lecture.sourceType.rawValue,
            "createdAt": Timestamp(date: lecture.createdAt),
            "durationSec": lecture.duration.timeInterval,
            "status": lecture.status.rawValue,
            "transcript": lecture.transcript,
            "summaryShort": lecture.summaryShort,
            "summaryLong": lecture.summaryLong,
            "flashcards": lecture.flashcards.map {
                [
                    "id": $0.id.uuidString,
                    "question": $0.question,
                    "answer": $0.answer
                ]
            },
            "quiz": lecture.quiz.map {
                [
                    "id": $0.id.uuidString,
                    "question": $0.question,
                    "options": $0.options,
                    "correctIndex": $0.correctIndex
                ]
            },
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let pdfPageCount = lecture.pdfPageCount {
            data["pdfPageCount"] = pdfPageCount
        } else {
            data["pdfPageCount"] = FieldValue.delete()
        }

        if let sourceURL = lecture.sourceURL {
            data["sourceURL"] = sourceURL.absoluteString
        } else {
            data["sourceURL"] = FieldValue.delete()
        }

        if let youtubeVideoID = lecture.youtubeVideoID {
            data["youtubeVideoID"] = youtubeVideoID
        } else {
            data["youtubeVideoID"] = FieldValue.delete()
        }

        if let folderID = lecture.folderID {
            data["folderID"] = folderID.uuidString
        } else {
            data["folderID"] = FieldValue.delete()
        }

        if let processingErrorMessage = lecture.processingErrorMessage {
            data["errorMessage"] = processingErrorMessage
        } else {
            data["errorMessage"] = FieldValue.delete()
        }

        return data
    }

    static func lecture(
        from data: [String: Any],
        fallbackDocumentID: String,
        preservedLocalAudioURL: URL? = nil
    ) -> Lecture? {
        let lectureID = UUID(uuidString: stringValue(for: "id", in: data) ?? fallbackDocumentID)
        guard let lectureID else {
            return nil
        }

        let createdAt = dateValue(for: "createdAt", in: data) ?? .now
        let duration = doubleValue(for: "durationSec", in: data) ?? 0

        return Lecture(
            id: lectureID,
            title: stringValue(for: "title", in: data) ?? String(localized: "Untitled Lecture"),
            sourceType: LectureSourceType(rawValue: stringValue(for: "sourceType", in: data) ?? "") ?? .audio,
            audioURL: preservedLocalAudioURL,
            pdfPageCount: intValue(for: "pdfPageCount", in: data),
            sourceURL: urlValue(for: "sourceURL", in: data),
            youtubeVideoID: stringValue(for: "youtubeVideoID", in: data),
            folderID: uuidValue(for: "folderID", in: data),
            createdAt: createdAt,
            duration: .seconds(duration),
            status: LectureStatus(rawValue: stringValue(for: "status", in: data) ?? "") ?? .draft,
            transcript: stringValue(for: "transcript", in: data) ?? "",
            summaryShort: stringValue(for: "summaryShort", in: data) ?? "",
            summaryLong: stringValue(for: "summaryLong", in: data) ?? "",
            flashcards: flashcardsValue(for: "flashcards", in: data),
            quiz: quizValue(for: "quiz", in: data),
            processingErrorMessage: stringValue(for: "errorMessage", in: data)
        )
    }

    private static func stringValue(for key: String, in data: [String: Any]) -> String? {
        data[key] as? String
    }

    private static func doubleValue(for key: String, in data: [String: Any]) -> Double? {
        if let value = data[key] as? Double {
            return value
        }

        if let value = data[key] as? Int {
            return Double(value)
        }

        return nil
    }

    private static func intValue(for key: String, in data: [String: Any]) -> Int? {
        if let value = data[key] as? Int {
            return value
        }

        if let value = data[key] as? Double {
            return Int(value)
        }

        return nil
    }

    private static func dateValue(for key: String, in data: [String: Any]) -> Date? {
        if let timestamp = data[key] as? Timestamp {
            return timestamp.dateValue()
        }

        return data[key] as? Date
    }

    private static func urlValue(for key: String, in data: [String: Any]) -> URL? {
        guard let string = data[key] as? String else {
            return nil
        }

        return URL(string: string)
    }

    private static func uuidValue(for key: String, in data: [String: Any]) -> UUID? {
        guard let string = data[key] as? String else {
            return nil
        }

        return UUID(uuidString: string)
    }

    private static func flashcardsValue(for key: String, in data: [String: Any]) -> [Flashcard] {
        let values = data[key] as? [[String: Any]] ?? []

        return values.map { item in
            Flashcard(
                id: UUID(uuidString: item["id"] as? String ?? "") ?? UUID(),
                question: item["question"] as? String ?? "",
                answer: item["answer"] as? String ?? ""
            )
        }
    }

    private static func quizValue(for key: String, in data: [String: Any]) -> [QuizQuestion] {
        let values = data[key] as? [[String: Any]] ?? []

        return values.map { item in
            QuizQuestion(
                id: UUID(uuidString: item["id"] as? String ?? "") ?? UUID(),
                question: item["question"] as? String ?? "",
                options: item["options"] as? [String] ?? [],
                correctIndex: item["correctIndex"] as? Int ?? 0
            )
        }
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        TimeInterval(components.seconds) + (TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000)
    }
}
