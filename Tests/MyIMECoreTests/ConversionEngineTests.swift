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
    func separatesExactAndPrefixCandidatesInOneLookup() {
        let engine = ConversionEngine(entries: [
            DictionaryEntry(reading: "mi", candidates: ["実", "見る"]),
            DictionaryEntry(reading: "miru", candidates: ["見る", "診る"])
        ])

        #expect(
            engine.candidateGroups(matching: "mi")
                == DictionaryCandidateGroups(
                    exact: ["実", "見る"],
                    prefix: ["診る"]
                )
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

    @Test
    func mergesLayersWithEarlierLayerFirst() {
        let engine = ConversionEngine(layers: [
            [
                DictionaryEntry(
                    reading: "miru",
                    candidates: ["観る", "見る"]
                )
            ],
            [
                DictionaryEntry(
                    reading: "miru",
                    candidates: ["見る", "診る"]
                )
            ]
        ])

        #expect(engine.candidates(for: "miru") == ["観る", "見る", "診る"])
    }

    @Test
    func limitsPrefixCandidates() {
        #expect(engine.candidates(matching: "m", limit: 2) == ["見る", "診る"])
        #expect(engine.candidates(matching: "m", limit: 0).isEmpty)
    }

    @Test
    func returnsAllCandidatesWithoutLimit() {
        #expect(
            engine.candidates(matching: "m")
                == ["見る", "診る", "観る"]
        )
    }

    @Test
    func searchesUnsortedEntriesInReadingOrder() {
        let engine = ConversionEngine(entries: [
            DictionaryEntry(reading: "miru", candidates: ["見る"]),
            DictionaryEntry(reading: "mikan", candidates: ["蜜柑"]),
            DictionaryEntry(reading: "mijikai", candidates: ["短い"])
        ])

        #expect(
            engine.candidates(matching: "mi")
                == ["短い", "蜜柑", "見る"]
        )
    }

    @Test
    func normalizesInputAndDictionaryReadings() {
        let engine = ConversionEngine(entries: [
            DictionaryEntry(reading: "hizuke", candidates: ["日付"])
        ])

        #expect(engine.candidates(for: "hiduke") == ["日付"])
        #expect(engine.candidates(matching: "hidu") == ["日付"])
    }

    @Test
    func findsReadingsForCandidate() {
        let engine = ConversionEngine(entries: [
            DictionaryEntry(reading: "readme", candidates: ["README"]),
            DictionaryEntry(reading: "setsumei", candidates: ["説明", "README"])
        ])

        #expect(engine.readings(for: "README") == ["readme", "setsumei"])
        #expect(engine.readings(for: "未登録").isEmpty)
    }
}
