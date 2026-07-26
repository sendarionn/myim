import Testing
@testable import MyIMECore

struct ConversionEngineTests {
    private let engine = ConversionEngine(entries: [
        DictionaryEntry(reading: "miru", candidates: ["見る", "診る", "観る"])
    ])

    @Test
    func returnsCandidatesForExactReading() {
        #expect(engine.candidates(for: "miru") == ["見る", "診る", "観る"])
    }

    @Test
    func returnsNoCandidatesForUnknownOrPartialReading() {
        #expect(engine.candidates(for: "mir").isEmpty)
        #expect(engine.candidates(for: "unknown").isEmpty)
    }
}
