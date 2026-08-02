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
            JapaneseSymbolConverter.candidates(for: ",") == [",", "、", "，"]
        )
        #expect(
            JapaneseSymbolConverter.candidates(for: "[")
                == ["[", "［", "「", "『", "【"]
        )
        #expect(
            JapaneseSymbolConverter.candidates(for: "-")
                == ["-", "－", "ー", "―", "−", "—"]
        )
        #expect(
            JapaneseSymbolConverter.candidates(for: "=")
                == ["=", "＝", "≒", "≠"]
        )
        #expect(
            JapaneseSymbolConverter.candidates(for: "|") == ["|", "｜"]
        )
        #expect(JapaneseSymbolConverter.candidates(for: "zl") == ["→"])
        #expect(JapaneseSymbolConverter.candidates(for: "zh") == ["←"])
        #expect(JapaneseSymbolConverter.candidates(for: "zk") == ["↑"])
        #expect(JapaneseSymbolConverter.candidates(for: "zj") == ["↓"])
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
        #expect(
            RomanizedReadingNormalizer.dictionaryReading(from: "hiduke")
                == "hizuke"
        )
    }

    @Test
    func normalizedReadingsFindDictionaryCandidates() {
        let engine = ConversionEngine(entries: [
            DictionaryEntry(reading: "tsuujou", candidates: ["通常"]),
            DictionaryEntry(reading: "fukumu", candidates: ["含む"]),
            DictionaryEntry(reading: "shuusei", candidates: ["修正"]),
            DictionaryEntry(reading: "hizuke", candidates: ["日付"])
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
        #expect(engine.candidates(for: "hiduke") == ["日付"])
        #expect(
            engine.candidates(
                for: RomanizedReadingNormalizer.dictionaryReading(
                    from: "shuusei"
                )
            ) == ["修正"]
        )
    }

    @Test
    func createsUnvoicedInitialLookupForRendaku() {
        #expect(
            RomanizedReadingNormalizer.dictionaryLookupReadings(
                from: "doori"
            ) == ["doori", "toori"]
        )
        #expect(
            RomanizedReadingNormalizer.dictionaryLookupReadings(
                from: "gawa"
            ) == ["gawa", "kawa"]
        )
        #expect(
            RomanizedReadingNormalizer.dictionaryLookupReadings(
                from: "tsuujou"
            ) == ["tsuujou"]
        )
    }

    @Test
    func rendakuLookupFindsUnvoicedDictionaryCandidate() {
        let engine = ConversionEngine(entries: [
            DictionaryEntry(reading: "doori", candidates: ["どおり"]),
            DictionaryEntry(reading: "toori", candidates: ["通り"])
        ])
        let candidates =
            RomanizedReadingNormalizer.dictionaryLookupReadings(
                from: "doori"
            )
            .flatMap {
                engine.candidates(for: $0)
            }

        #expect(candidates == ["どおり", "通り"])
    }
}
