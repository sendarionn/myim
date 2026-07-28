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

    @Test
    func returnsCandidatesForReadingPrefix() {
        #expect(
            engine.candidates(matching: "m")
                == ["見る", "診る", "観る"]
        )
        #expect(
            engine.candidates(matching: "mir")
                == ["見る", "診る", "観る"]
        )
    }

    @Test
    func prioritizesExactReadingAndRemovesDuplicates() {
        let engine = ConversionEngine(entries: [
            DictionaryEntry(reading: "mi", candidates: ["実", "見る"]),
            DictionaryEntry(reading: "miru", candidates: ["見る", "診る"])
        ])

        #expect(
            engine.candidates(matching: "mi")
                == ["実", "見る", "診る"]
        )
    }

    @Test
    func returnsNoCandidatesForEmptyOrUnknownPrefix() {
        #expect(engine.candidates(matching: "").isEmpty)
        #expect(engine.candidates(matching: "unknown").isEmpty)
    }
}
