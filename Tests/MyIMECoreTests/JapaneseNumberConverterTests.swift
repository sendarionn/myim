import Testing
@testable import MyIMECore

@Suite
struct JapaneseNumberConverterTests {
    @Test
    func createsSingleDigitCandidates() {
        #expect(
            JapaneseNumberConverter.candidates(for: "1")
                == ["1", "①", "１", "一", "壱"]
        )
        #expect(
            JapaneseNumberConverter.candidates(for: "0")
                == ["0", "⓪", "０", "零", "〇"]
        )
    }

    @Test
    func createsCandidatesThroughTwenty() {
        #expect(
            JapaneseNumberConverter.candidates(for: "12")
                == ["12", "⑫", "１２", "十二"]
        )
        #expect(
            JapaneseNumberConverter.candidates(for: "20")
                == ["20", "⑳", "２０", "二十"]
        )
    }

    @Test
    func createsKanjiCandidatesForLargeNumbers() {
        #expect(JapaneseNumberConverter.kanjiCandidates(for: "1000") == ["千"])
        #expect(JapaneseNumberConverter.kanjiCandidates(for: "1000000") == ["百万"])
        #expect(JapaneseNumberConverter.kanjiCandidates(for: "10001") == ["一万一"])
        #expect(
            JapaneseNumberConverter.kanjiCandidates(for: "123456789")
                == ["一億二千三百四十五万六千七百八十九"]
        )
    }

    @Test
    func rejectsUnsupportedInput() {
        #expect(JapaneseNumberConverter.candidates(for: "").isEmpty)
        #expect(JapaneseNumberConverter.candidates(for: "01").isEmpty)
        #expect(
            JapaneseNumberConverter.candidates(for: "21")
                == ["21", "２１", "二十一"]
        )
        #expect(JapaneseNumberConverter.candidates(for: "1a").isEmpty)
        #expect(JapaneseNumberConverter.candidates(for: "18446744073709551616").isEmpty)
    }
}
