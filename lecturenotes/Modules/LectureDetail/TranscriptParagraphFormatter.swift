import Foundation
import NaturalLanguage

/// Breaks a raw transcript into readable paragraphs.
///
/// Audio transcription returns one long run of text, while PDF text is hard-wrapped at
/// every line. Blank lines are kept as paragraph breaks and single line breaks are
/// re-flowed into spaces. Any block longer than `sentencesPerParagraph` sentences is then
/// split on sentence boundaries detected with `NLTokenizer`, which handles every
/// language we support.
nonisolated enum TranscriptParagraphFormatter {
    static let sentencesPerParagraph = 4

    static func paragraphs(from transcript: String) -> [String] {
        transcript
            .replacing("\r\n", with: "\n")
            .split(separator: /\n[ \t]*\n/)
            .map { block in
                block
                    .split(whereSeparator: \.isNewline)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            }
            .filter { !$0.isEmpty }
            .flatMap(splitIntoParagraphs)
    }

    private static func splitIntoParagraphs(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text

        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = text[range].trimmingCharacters(in: .whitespaces)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            return true
        }

        guard sentences.count > sentencesPerParagraph else {
            return [text]
        }

        return stride(from: 0, to: sentences.count, by: sentencesPerParagraph).map { start in
            let end = min(start + sentencesPerParagraph, sentences.count)
            return sentences[start..<end].joined(separator: " ")
        }
    }
}
