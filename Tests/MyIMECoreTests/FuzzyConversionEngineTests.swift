import Testing
@testable import MyIMECore

@Suite
struct FuzzyConversionEngineTests {
    private let engine = FuzzyConversionEngine(entries: [
        DictionaryEntry(reading: "kakujuu", candidates: ["拡充"]),
        DictionaryEntry(reading: "kakudai", candidates: ["拡大"]),
        DictionaryEntry(reading: "shuusei", candidates: ["修正"]),
        DictionaryEntry(reading: "hiduke", candidates: ["日付"])
    ])

    @Test
    func findsSingleCharacterTypo() {
        #expect(engine.matches(for: "kakuju").first == FuzzyConversionMatch(
            reading: "kakujuu",
            candidates: ["拡充"],
            distance: 1
        ))
    }

    @Test
    func findsTransposedCharacters() {
        #expect(engine.matches(for: "hiduek").first?.candidates == ["日付"])
        #expect(engine.matches(for: "hiduek").first?.distance == 1)
    }

    @Test
    func normalizesRomanizationBeforeSearching() {
        #expect(engine.matches(for: "syuusei", maximumDistance: 1).isEmpty)
    }

    @Test
    func doesNotReturnExactReading() {
        #expect(engine.matches(for: "kakujuu").allSatisfy {
            $0.reading != "kakujuu"
        })
    }

    @Test
    func avoidsShortNoisySuggestionsByDefault() {
        #expect(engine.matches(for: "hid").isEmpty)
    }

    @Test
    func limitsAndRanksMatches() {
        let matches = engine.matches(
            for: "kakuju",
            maximumDistance: 2,
            limit: 1
        )
        #expect(matches.count == 1)
        #expect(matches.first?.candidates == ["拡充"])
    }
}
