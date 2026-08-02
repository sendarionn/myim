import Testing
@testable import MyIMECore

@Suite
struct SortedConversionEngineTests {
    private let engine = SortedConversionEngine(entries: [
        DictionaryEntry(reading: "かく", candidates: ["書く", "各"]),
        DictionaryEntry(reading: "かくじゅう", candidates: ["拡充"]),
        DictionaryEntry(reading: "かんがえる", candidates: ["考える"])
    ])

    @Test func returnsExactCandidates() {
        #expect(engine.candidates(for: "かくじゅう") == ["拡充"])
    }

    @Test func returnsPrefixCandidatesFromLowerBound() {
        #expect(engine.candidates(matching: "かく") == ["書く", "各", "拡充"])
    }

    @Test func limitsPrefixCandidates() {
        #expect(engine.candidates(matching: "かく", limit: 2) == ["書く", "各"])
    }
}
