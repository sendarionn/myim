import Testing
@testable import MyIMECore

@Suite
struct RomajiConverterTests {
    @Test
    func convertsExtendedSyllables() {
        let converter = RomajiConverter()

        #expect(converter.hiragana(from: "thi") == "てぃ")
        #expect(converter.hiragana(from: "cha-to") == "ちゃーと")
        #expect(converter.hiragana(from: "matcha") == "まっちゃ")
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
    }
}
