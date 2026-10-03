import Testing
@testable import MyIMECore

@Suite
struct CandidateFilterQuerySourceTests {
    @Test
    func generatesFilterInputConversionsFromDictionarySources() {
        let source = CandidateFilterQuerySource(
            userEngine: LayeredConversionEngine(engines: [
                ConversionEngine(entries: [
                    DictionaryEntry(reading: "ki", candidates: ["木"])
                ])
            ]),
            basicEngine: ConversionEngine(entries: [
                DictionaryEntry(reading: "ki", candidates: ["気"])
            ]),
            systemEngine: IndexedDictionaryEngine()
        )

        let candidates = source.candidates(
            for: "ki",
            selectionHistory: CandidateSelectionHistory()
        )

        #expect(candidates.first == "ki")
        #expect(candidates.contains("き"))
        #expect(candidates.contains("キ"))
        #expect(candidates.contains("木"))
        #expect(candidates.contains("気"))
        #expect(Set(candidates).count == candidates.count)
    }

    @Test
    func appliesSelectionHistoryInsideTheDirectCandidateGroup() {
        var history = CandidateSelectionHistory()
        history.record("気", readings: ["ki"])
        let source = CandidateFilterQuerySource(
            userEngine: LayeredConversionEngine(engines: [
                ConversionEngine(entries: [
                    DictionaryEntry(reading: "ki", candidates: ["木", "気"])
                ])
            ]),
            basicEngine: ConversionEngine(entries: []),
            systemEngine: IndexedDictionaryEngine()
        )

        let candidates = source.candidates(
            for: "ki",
            selectionHistory: history
        )

        #expect(candidates.firstIndex(of: "気")! < candidates.firstIndex(of: "木")!)
    }

    @Test
    func keepsTheEmptyDraftAsOneDirectChoice() {
        let source = CandidateFilterQuerySource(
            userEngine: LayeredConversionEngine(engines: []),
            basicEngine: ConversionEngine(entries: []),
            systemEngine: IndexedDictionaryEngine()
        )

        #expect(source.candidates(
            for: "",
            selectionHistory: CandidateSelectionHistory()
        ) == [""])
    }
}
