import Testing
@testable import MyIMECore

@Suite
struct SupplementalDictionaryTests {
    @Test
    func suppliesMissingKanjiCandidates() {
        let engine = ConversionEngine(entries: SupplementalDictionary.entries)
        #expect(engine.candidates(for: "kakujuu") == ["拡充"])
    }
}
