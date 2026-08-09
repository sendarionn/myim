import Foundation
import Testing
@testable import MyIMECore

@Suite
struct SemanticDictionaryTests {
    private let entries = [
        SemanticDictionaryEntry(
            id: "00001_kangaeru",
            headword: "考える",
            reading: "kangaeru",
            partOfSpeech: "verb (ichidan)",
            glosses: ["to think", "to consider"],
            explanations: ["To use the mind to examine something"],
            source: "TKGJE"
        ),
        SemanticDictionaryEntry(
            id: "00002_omou",
            headword: "思う",
            reading: "omou",
            glosses: ["to feel", "to think"],
            source: "TKGJE"
        )
    ]

    @Test
    func roundTripsJSONL() throws {
        let data = try SemanticDictionaryJSONL.encode(entries)
        #expect(try SemanticDictionaryJSONL.decode(data) == entries)
    }

    @Test
    func ignoresBlankJSONLLines() throws {
        var data = try SemanticDictionaryJSONL.encode([entries[0]])
        data.append(contentsOf: "  \n".utf8)
        #expect(try SemanticDictionaryJSONL.decode(data) == [entries[0]])
    }

    @Test
    func searchesHeadwordReadingAndGloss() {
        let engine = SemanticDictionarySearchEngine(entries: entries)
        #expect(engine.matches(for: "考える").first?.entry.id == "00001_kangaeru")
        #expect(engine.matches(for: "omou").first?.entry.id == "00002_omou")
        #expect(engine.matches(for: "consider").first?.entry.id == "00001_kangaeru")
    }

    @Test
    func limitsResults() {
        let engine = SemanticDictionarySearchEngine(entries: entries)
        #expect(engine.matches(for: "think", limit: 1).count == 1)
    }
}
