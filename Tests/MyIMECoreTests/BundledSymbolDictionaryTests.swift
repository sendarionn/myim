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
}
