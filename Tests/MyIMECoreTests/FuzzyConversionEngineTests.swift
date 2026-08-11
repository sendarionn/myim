import Testing
@testable import MyIMECore

@Suite
struct FuzzyConversionEngineTests {
    private let engine = FuzzyConversionEngine(entries: [
        DictionaryEntry(reading: "kakujuu", candidates: ["拡充"]),
        DictionaryEntry(reading: "kakudai", candidates: ["拡大"]),
        DictionaryEntry(reading: "shuusei", candidates: ["修正"]),
        DictionaryEntry(reading: "hiduke", candidates: ["日付"]),
        DictionaryEntry(reading: "genin", candidates: ["原因"]),
        DictionaryEntry(reading: "aimai", candidates: ["曖昧"]),
        DictionaryEntry(reading: "hitsuyou", candidates: ["必要"]),
        DictionaryEntry(reading: "wo", candidates: ["を"]),
        DictionaryEntry(reading: "konnichiha", candidates: ["こんにちは"]),
        DictionaryEntry(reading: "shinbun", candidates: ["新聞"]),
        DictionaryEntry(reading: "toukyou", candidates: ["東京"])
    ])

    @Test
    func findsSingleCharacterTypo() {
        #expect(engine.matches(for: "kakuju").first == FuzzyConversionMatch(
            reading: "kakujuu",
            candidates: ["拡充"],
            distance: 0
        ))
    }

    @Test
    func findsSingleConsonantSubstitution() {
        let match = engine.matches(for: "ainai").first
        #expect(match?.reading == "aimai")
        #expect(match?.candidates == ["曖昧"])
        #expect(match?.distance == 1)
    }

    @Test
    func findsAdjacentKeyboardTypoForShortReading() {
        let match = engine.matches(for: "eo").first
        #expect(match?.reading == "wo")
        #expect(match?.candidates == ["を"])
        #expect(match?.distance == 1)
    }

    @Test
    func findsAdjacentKeyboardTypoForLongReading() {
        let match = engine.matches(for: "shjusei").first
        #expect(match?.reading == "shuusei")
        #expect(match?.candidates == ["修正"])
        #expect(match?.distance == 1)
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

    @Test
    func acceptsDoubledMoraicNInput() {
        let match = engine.matches(for: "genninn").first
        #expect(match?.reading == "genin")
        #expect(match?.candidates == ["原因"])
    }

    @Test
    func acceptsSingleTrailingMoraicNInput() {
        let match = engine.matches(for: "gennin").first
        #expect(match?.reading == "genin")
        #expect(match?.candidates == ["原因"])
        #expect(match?.distance == 0)
    }

    @Test
    func preservesCanonicalDoubleNReading() {
        #expect(engine.matches(for: "konnichiha").allSatisfy {
            $0.reading != "konnichiha"
        })
    }

    @Test
    func acceptsApostropheSeparatedMoraicN() {
        #expect(engine.matches(for: "gen'in").first?.candidates == ["原因"])
    }

    @Test
    func acceptsLabialNasalRomanization() {
        #expect(engine.matches(for: "shimbun").first?.candidates == ["新聞"])
    }

    @Test
    func acceptsOmittedLongVowels() {
        #expect(engine.matches(for: "tokyo").first?.candidates == ["東京"])
    }

    @Test
    func findsTwoEditTypoForSevenCharacterInput() {
        let match = engine.matches(for: "hiruyou").first
        #expect(match?.reading == "hitsuyou")
        #expect(match?.candidates == ["必要"])
        #expect(match?.distance == 2)
    }
}
