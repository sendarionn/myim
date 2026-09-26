import Foundation
import Testing
@testable import MyIMECore

@Suite("BundledSymbolDictionaryTests")
struct BundledSymbolDictionaryTests {
    @Test
    func resolvesSymbolNamesFromIndependentTSVDictionary() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let dictionaryURL = repositoryRoot.appendingPathComponent(
            "Sources/MyIMEMacOS/Resources/symbol-dictionary.tsv"
        )
        let text = try String(contentsOf: dictionaryURL, encoding: .utf8)
        let engine = ConversionEngine(entries: try DictionaryParser().parse(text))

        #expect(engine.candidates(for: "ongusutoro-mu") == ["Å"])
        #expect(engine.candidates(for: "be-ta") == ["β"])
        #expect(engine.candidates(for: "arufa") == ["α"])
        #expect(engine.candidates(for: "o-mu") == ["Ω"])
        #expect(engine.candidates(for: "nyu-") == ["ν"])
        #expect(engine.candidates(for: "myu-") == ["μ"])
        #expect(engine.candidates(for: "kushii") == ["ξ"])
    }

    @Test
    func doesNotRestoreSingleLetterSymbolAliases() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let dictionaryURL = repositoryRoot.appendingPathComponent(
            "Sources/MyIMEMacOS/Resources/symbol-dictionary.tsv"
        )
        let text = try String(contentsOf: dictionaryURL, encoding: .utf8)
        let engine = ConversionEngine(entries: try DictionaryParser().parse(text))

        #expect(engine.candidates(for: "a").isEmpty)
        #expect(engine.candidates(for: "b").isEmpty)
    }

    @Test
    func symbolCandidatesSurviveTheFullLongVowelPostProcessing() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let dictionaryURL = repositoryRoot.appendingPathComponent(
            "Sources/MyIMEMacOS/Resources/symbol-dictionary.tsv"
        )
        let text = try String(contentsOf: dictionaryURL, encoding: .utf8)
        let engine = ConversionEngine(entries: try DictionaryParser().parse(text))

        for (input, expected) in [("o-mu", "Ω"), ("nyu-", "ν")] {
            let readings = RomajiCanonicalizer.dictionaryLookupInputs(from: input)
            let exact = readings.flatMap {
                engine.candidateGroups(matching: $0).exact
            }
            let final = LongVowelNotationCandidateFilter.candidates(
                exact,
                for: input,
                preserving: Set(exact)
            )
            #expect(final.contains(expected))
        }
    }
}
