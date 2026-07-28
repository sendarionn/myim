import Testing
@testable import MyIMECore

@Suite
struct RomajiConverterTests {
    @Test
    func convertsExtendedSyllables() {
        let converter = RomajiConverter()

        #expect(converter.hiragana(from: "thi") == "てぃ")
        #expect(converter.katakana(from: "thi") == "ティ")
        #expect(converter.hiragana(from: "Tsuujou") == "つうじょう")
        #expect(converter.hiragana(from: "cha-to") == "ちゃーと")
        #expect(converter.hiragana(from: "matcha") == "まっちゃ")
    }

    @Test
    func createsJapaneseSymbolCandidates() {
        #expect(
            JapaneseSymbolConverter.candidates(for: ",") == ["、", "，"]
        )
        #expect(
            JapaneseSymbolConverter.candidates(for: "[") == ["「", "『", "【", "［"]
        )
        #expect(JapaneseSymbolConverter.candidates(for: "a").isEmpty)
    }

    @Test
    func rejectsIncompleteInput() {
        #expect(RomajiConverter().hiragana(from: "th") == nil)
    }

    @Test
    func expandsLongVowelHyphensForDictionarySearch() {
        #expect(
            RomanizedReadingNormalizer.dictionaryReading(from: "cha-to")
                == "chaato"
        )
        #expect(
            RomanizedReadingNormalizer.dictionaryReading(from: "ko-hi-")
                == "koohii"
        )
        #expect(
            RomanizedReadingNormalizer.dictionaryReading(from: "tuujou")
                == "tsuujou"
        )
        #expect(
            RomanizedReadingNormalizer.dictionaryReading(from: "hukumu")
                == "fukumu"
        )
        #expect(
            RomanizedReadingNormalizer.dictionaryReading(from: "syuusei")
                == "shuusei"
        )
        #expect(
            RomanizedReadingNormalizer.dictionaryReading(from: "shuusei")
                == "shuusei"
        )
    }

    @Test
    func normalizedReadingsFindDictionaryCandidates() {
        let engine = ConversionEngine(entries: [
            DictionaryEntry(reading: "tsuujou", candidates: ["通常"]),
            DictionaryEntry(reading: "fukumu", candidates: ["含む"]),
            DictionaryEntry(reading: "shuusei", candidates: ["修正"])
        ])

        #expect(
            engine.candidates(
                for: RomanizedReadingNormalizer.dictionaryReading(
                    from: "tuujou"
                )
            ) == ["通常"]
        )
        #expect(
            engine.candidates(
                for: RomanizedReadingNormalizer.dictionaryReading(
                    from: "hukumu"
                )
            ) == ["含む"]
        )
        #expect(
            engine.candidates(
                for: RomanizedReadingNormalizer.dictionaryReading(
                    from: "syuusei"
                )
            ) == ["修正"]
        )
        #expect(
            engine.candidates(
                for: RomanizedReadingNormalizer.dictionaryReading(
                    from: "shuusei"
                )
            ) == ["修正"]
        )
    }
}
