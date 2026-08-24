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
        #expect(converter.hiragana(from: "sajesuto") == "さじぇすと")
        #expect(converter.katakana(from: "sajesuto") == "サジェスト")
        #expect(converter.katakana(from: "shefu") == "シェフ")
        #expect(converter.katakana(from: "che-n") == "チェーン")
        #expect(converter.katakana(from: "kwa-tetto") == "クァーテット")
        #expect(converter.katakana(from: "twuin") == "トゥイン")
    }

    @Test
    func createsJapaneseSymbolCandidates() {
        #expect(
            JapaneseSymbolConverter.candidates(for: ",") == ["、", "，"]
        )
        #expect(
            JapaneseSymbolConverter.candidates(for: "[")
                == ["「", "［", "『", "【"]
        )
        #expect(
            JapaneseSymbolConverter.candidates(for: "]")
                == ["」", "］", "』", "】"]
        )
        #expect(
            JapaneseSymbolConverter.candidates(for: "(")
                == ["（", "「", "『"]
        )
        #expect(
            JapaneseSymbolConverter.candidates(for: "-")
                == ["－", "ー", "―", "−", "—"]
        )
        #expect(
            JapaneseSymbolConverter.candidates(for: "=")
                == ["＝", "≒", "≠"]
        )
        for input in ["z-", "z[", "z]", "z,", "z.", "z/"] {
            #expect(JapaneseSymbolConverter.candidates(for: input).isEmpty)
        }
        #expect(
            JapaneseSymbolConverter.candidates(for: "|") == ["｜"]
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
            RomajiCanonicalizer.canonicalInput(from: "cha-to")
                == "chaato"
        )
        #expect(
            RomajiCanonicalizer.canonicalInput(from: "ko-hi-")
                == "koohii"
        )
        #expect(
            RomajiCanonicalizer.canonicalInput(from: "tuujou")
                == "tsuujou"
        )
        #expect(
            RomajiCanonicalizer.canonicalInput(from: "hukumu")
                == "fukumu"
        )
        #expect(
            RomajiCanonicalizer.canonicalInput(from: "syuusei")
                == "shuusei"
        )
        #expect(
            RomajiCanonicalizer.canonicalInput(from: "shuusei")
                == "shuusei"
        )
        #expect(
            RomajiCanonicalizer.canonicalInput(from: "hiduke")
                == "hizuke"
        )
    }

    @Test
    func canonicalizesOnlyCompleteJapaneseRomajiInput() {
        #expect(RomajiCanonicalizer.canonicalInput(from: "siru") == "shiru")
        #expect(RomajiCanonicalizer.canonicalInput(from: "syuusei") == "shuusei")
        #expect(RomajiCanonicalizer.canonicalInput(from: "rlj") == "rlj")
        #expect(RomajiCanonicalizer.canonicalInput(from: "chatgpt") == "chatgpt")
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
                for: RomajiCanonicalizer.canonicalInput(
                    from: "tuujou"
                )
            ) == ["通常"]
        )
        #expect(
            engine.candidates(
                for: RomajiCanonicalizer.canonicalInput(
                    from: "hukumu"
                )
            ) == ["含む"]
        )
        #expect(
            engine.candidates(
                for: RomajiCanonicalizer.canonicalInput(
                    from: "syuusei"
                )
            ) == ["修正"]
        )
        #expect(engine.candidates(for: "hiduke") == ["日付"])
        #expect(
            engine.candidates(
                for: RomajiCanonicalizer.canonicalInput(
                    from: "shuusei"
                )
            ) == ["修正"]
        )
    }

    @Test
    func keepsVoicedAndUnvoicedInitialReadingsSeparate() {
        #expect(
            RomajiCanonicalizer.dictionaryLookupInputs(
                from: "doori"
            ) == ["doori"]
        )
        #expect(
            RomajiCanonicalizer.dictionaryLookupInputs(
                from: "gawa"
            ) == ["gawa"]
        )
        #expect(
            RomajiCanonicalizer.dictionaryLookupInputs(
                from: "zumi"
            ) == ["zumi"]
        )
    }

    @Test
    func voicedLookupDoesNotFindUnvoicedDictionaryCandidate() {
        let engine = ConversionEngine(entries: [
            DictionaryEntry(reading: "doori", candidates: ["どおり"]),
            DictionaryEntry(reading: "toori", candidates: ["通り"])
        ])
        let candidates =
            RomajiCanonicalizer.dictionaryLookupInputs(
                from: "doori"
            )
            .flatMap {
                engine.candidates(for: $0)
            }

        #expect(candidates == ["どおり"])
    }
}
