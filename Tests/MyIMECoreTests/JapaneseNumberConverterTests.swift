import Testing
@testable import MyIMECore

@Suite
struct JapaneseNumberConverterTests {
    @Test
    func createsSingleDigitCandidates() {
        #expect(
            JapaneseNumberConverter.candidates(for: "1")
                == ["①", "１", "一", "壱"]
        )
        #expect(
            JapaneseNumberConverter.candidates(for: "0")
                == ["⓪", "０", "零", "〇"]
        )
    }

    @Test
    func createsCandidatesThroughTwenty() {
        #expect(
            JapaneseNumberConverter.candidates(for: "12")
                == ["⑫", "１２", "十二"]
        )
        #expect(
            JapaneseNumberConverter.candidates(for: "20")
                == ["⑳", "２０", "二十"]
        )
    }

    @Test
    func rejectsUnsupportedInput() {
        #expect(JapaneseNumberConverter.candidates(for: "").isEmpty)
        #expect(JapaneseNumberConverter.candidates(for: "01").isEmpty)
        #expect(JapaneseNumberConverter.candidates(for: "21").isEmpty)
        #expect(JapaneseNumberConverter.candidates(for: "1a").isEmpty)
    }
}
