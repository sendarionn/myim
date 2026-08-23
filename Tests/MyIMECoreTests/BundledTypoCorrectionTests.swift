import Foundation
import Testing
@testable import MyIMECore

@Suite(.serialized)
struct BundledTypoCorrectionTests {
    @Test
    func findsRepresentativeTyposInBundledDictionary() throws {
        let dictionaryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(
                "Sources/MyIMEMacOS/Resources/basic-dictionary.txt"
            )
        let dictionaryText = try String(
            contentsOf: dictionaryURL,
            encoding: .utf8
        )
        let baseEntries = try DictionaryParser().parse(dictionaryText)
        let entries = baseEntries
            + VerbInflectionCandidateGenerator.typoSearchEntries(
                from: baseEntries
            )
        let engine = FuzzyConversionEngine(entries: entries)

        let necessaryMatches = engine.matches(for: "hiruyou")
        #expect(necessaryMatches.contains {
            $0.candidates.contains("必要")
        })
        #expect(engine.matches(for: "susmete").contains {
            $0.candidates.contains("進めて")
        })
        let imeDictionaryURL = dictionaryURL
            .deletingLastPathComponent()
            .appendingPathComponent("mozc-dictionary.txt")
        let imeDictionary = try IndexedDictionaryEngine(
            contentsOf: imeDictionaryURL
        )
        #expect(RomajiKeyboardTypoGenerator.dictionaryMatches(
            for: "vaiyou",
            dictionary: imeDictionary
        ).contains {
            $0.reading == "baiyou" && $0.candidates.contains("培養")
        })
    }

    @Test
    func findsKeyboardTypoInIMEDictionary() {
        let dictionary = IndexedDictionaryEngine(
            data: Data("baiyou\n 培養\ngaiyou\n 概要\n".utf8)
        )
        let matches = RomajiKeyboardTypoGenerator.dictionaryMatches(
            for: "vaiyou",
            dictionary: dictionary
        )

        #expect(matches.first?.reading == "baiyou")
        #expect(matches.first?.candidates == ["培養"])
    }
}
