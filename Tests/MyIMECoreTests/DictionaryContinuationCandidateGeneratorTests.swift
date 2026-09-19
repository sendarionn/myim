import Foundation
import Testing
@testable import MyIMECore

@Suite
struct DictionaryContinuationCandidateGeneratorTests {
    @Test
    func suggestsTheUncommittedPartOfALongerDictionaryCandidate() {
        let generator = DictionaryContinuationCandidateGenerator(entries: [
            DictionaryEntry(
                reading: "yoroshikuonegaishimasu",
                candidates: ["よろしくお願いします"]
            )
        ])

        #expect(generator.candidates(after: "よろしく") == ["お願いします"])
    }

    @Test
    func ignoresExactAndUnrelatedCandidates() {
        let generator = DictionaryContinuationCandidateGenerator(entries: [
            DictionaryEntry(reading: "yoroshiku", candidates: ["よろしく"]),
            DictionaryEntry(reading: "arigatou", candidates: ["ありがとう"])
        ])

        #expect(generator.candidates(after: "よろしく").isEmpty)
    }

    @Test
    func suppressesNoisySingleCharacterPrefixes() {
        let generator = DictionaryContinuationCandidateGenerator(entries: [
            DictionaryEntry(reading: "nihon", candidates: ["日本"])
        ])

        #expect(generator.candidates(after: "日").isEmpty)
    }

    @Test
    func prefersTheShortestCompleteCandidate() {
        let generator = DictionaryContinuationCandidateGenerator(entries: [
            DictionaryEntry(
                reading: "yoroshikuonegaimoushiagemasu",
                candidates: ["よろしくお願い申し上げます"]
            ),
            DictionaryEntry(
                reading: "yoroshikuonegaishimasu",
                candidates: ["よろしくお願いします"]
            )
        ])

        #expect(generator.candidates(after: "よろしく") == [
            "お願いします", "お願い申し上げます"
        ])
    }

    @Test
    func suggestsContinuationFromTheBundledDictionary() throws {
        let dictionaryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(
                "Sources/MyIMEMacOS/Resources/basic-dictionary.tsv"
            )
        let text = try String(contentsOf: dictionaryURL, encoding: .utf8)
        let entries = try DictionaryParser().parse(text)
        let generator = DictionaryContinuationCandidateGenerator(
            entries: entries
        )

        #expect(generator.candidates(after: "よろしく").first == "お願いします")
    }
}
