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
        DictionaryEntry(reading: "toukyou", candidates: ["東京"]),
        DictionaryEntry(reading: "gakkou", candidates: ["学校"]),
        DictionaryEntry(reading: "deetabeesu", candidates: ["データベース"])
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
    func findsAdjacentKeyboardTypoAcrossDictionarySources() {
        let matches = RomajiKeyboardTypoGenerator.dictionaryMatches(
            for: "eo"
        ) { reading in
            reading == "wo" ? ["を"] : []
        }

        #expect(matches.first == FuzzyConversionMatch(
            reading: "wo",
            candidates: ["を"],
            distance: 1
        ))
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
        #expect(match?.distance == 1)
    }

    @Test
    func rejectsTwoUnrelatedConsonantEdits() {
        #expect(engine.matches(for: "hipuyou").allSatisfy {
            $0.reading != "hitsuyou"
        })
    }

    @Test
    func doesNotSuggestReadingThatOnlyAddsVoicing() {
        #expect(engine.matches(for: "kakkou").allSatisfy {
            $0.reading != "gakkou"
        })
    }

    @Test
    func findsMultipleErrorsOnlyInTheAggressiveSecondStage() {
        let match = engine.matches(for: "de-tsb-su").first {
            $0.reading == "deetabeesu"
        }

        #expect(match?.candidates == ["データベース"])
        #expect(match?.distance == 3)
        #expect(engine.matches(
            for: "de-tsb-su",
            maximumDistance: 2
        ).allSatisfy { $0.reading != "deetabeesu" })
    }

    @Test(arguments: [
        "dtbeesu",       // multiple missing vowels
        "de-tabe-su"     // multiple long-vowel notation differences
    ])
    func findsDatabaseAcrossPhoneticallyPlausibleErrors(_ input: String) {
        #expect(engine.matches(for: input).contains {
            $0.reading == "deetabeesu"
        })
    }

    @Test
    func findsMultipleAdjacentKeySubstitutions() {
        #expect(engine.matches(for: "jonnichiga").contains {
            $0.reading == "konnichiha"
        })
    }

    @Test
    func findsCombinedOmissionAndTransposition() {
        #expect(engine.matches(for: "konncihia").contains {
            $0.reading == "konnichiha"
        })
    }

    @Test
    func aggressiveSearchStillRejectsUnrelatedLongInput() {
        #expect(engine.matches(for: "qx-zvbnm").isEmpty)
    }

    @Test
    func closeCorrectionPreventsTheAggressiveFallback() {
        let rankedEngine = FuzzyConversionEngine(entries: [
            DictionaryEntry(
                reading: "de-tsb-sa",
                candidates: ["近い候補"]
            ),
            DictionaryEntry(
                reading: "deetabeesu",
                candidates: ["データベース"]
            )
        ])

        let matches = rankedEngine.matches(for: "de-tsb-su")

        #expect(matches.first?.candidates == ["近い候補"])
        #expect(matches.allSatisfy { $0.candidates != ["データベース"] })
    }

    @Test
    func doesNotDropAnIntentionalSymbolToCreateADictionaryReading() {
        let symbolEngine = FuzzyConversionEngine(entries: [
            DictionaryEntry(
                reading: "foo=barbaz",
                candidates: ["記号を含む入力"]
            ),
            DictionaryEntry(
                reading: "foobarbaz",
                candidates: ["記号なし"]
            ),
            DictionaryEntry(
                reading: "version",
                candidates: ["バージョン"]
            )
        ])

        let symbolMatches = symbolEngine.matches(for: "foo=barbaz")
        #expect(symbolMatches.allSatisfy {
            $0.reading != "foobarbaz"
        })
        #expect(symbolEngine.matches(for: "version10").allSatisfy {
            $0.reading != "version"
        })
    }
}
