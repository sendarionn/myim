import Foundation
import Testing
@testable import MyIMECore

@Suite
struct LiveConversionPhrasesTests {
    private func phrases() -> LiveConversionPhrases {
        LiveConversionPhrases(segments: LiveConversionSegment.phrases(of: [
            .init(surface: "今日", reading: "きょう"),
            .init(surface: "は", reading: "は"),
            .init(surface: "良い", reading: "よい"),
            .init(surface: "転機", reading: "てんき")
        ]))
    }

    @Test
    func kanaAtTheStartOfAWordGoesWithTheWordBefore() {
        let phrases = LiveConversionSegment.phrases(of: [
            .init(surface: "強", reading: "きょう"),
            .init(surface: "は良い", reading: "はよい"),
            .init(surface: "天気", reading: "てんき"),
            .init(surface: "コーヒー", reading: "こーひー"),
            .init(surface: "を飲む", reading: "をのむ")
        ])
        #expect(phrases.map(\.surface) == ["強は", "良い", "天気", "コーヒーを", "飲む"])
        #expect(phrases.map(\.reading) == ["きょうは", "よい", "てんき", "こーひーを", "のむ"])
    }

    @Test
    func kanaWordsGoWithTheWordBefore() {
        #expect(phrases().segments.map(\.surface) == ["今日は", "良い", "転機"])
        #expect(phrases().reading == "きょうはよいてんき")
    }

    @Test
    func theArrowsMoveFromTheLastPhrase() {
        var editing = phrases()
        editing.selectPrevious()
        #expect(editing.selectedSegment?.surface == "転機")
        editing.selectPrevious()
        #expect(editing.selectedSegment?.surface == "良い")
        editing.selectNext()
        #expect(editing.selectedSegment?.surface == "転機")
        #expect(editing.selectedTextRange == NSRange(location: 5, length: 2))
    }

    /// A corrected phrase changes only itself, and it and those before it
    /// are kept from the conversion of what is typed next
    @Test
    func aCorrectionChangesOnlyItsPhraseAndFixesIt() {
        var editing = phrases()
        editing.selectPrevious()
        editing.commitSelected("天気")
        #expect(editing.text == "今日は良い天気")
        #expect(editing.fixedReading == "きょうはよいてんき")
        editing.replaceUnfixed(with: [.init(surface: "です", reading: "です")])
        #expect(editing.text == "今日は良い天気です")
    }

    @Test
    func shiftMovesOneEndByAKanaAndBack() {
        var editing = phrases()
        editing.selectPrevious()
        editing.selectPrevious()
        // 良い: its left end takes は from 今日は, which stays in kana
        editing.adjust(toward: .left)
        #expect(editing.segments.map(\.reading) == ["きょう", "はよい", "てんき"])
        // 今日は gave は away and is to be converted again from きょう
        #expect(editing.phraseToConvert == 0)
        #expect(editing.selectedSegment?.reading == "はよい")
        // The opposite arrow gives it back
        editing.adjust(toward: .right)
        #expect(editing.selectedSegment?.reading == "よい")
        #expect(editing.segments[0].reading == "きょうは")
    }

    @Test
    func theRightEndTakesFromThePhraseAfter() {
        var editing = phrases()
        editing.selectPrevious()
        editing.selectPrevious()
        editing.adjust(toward: .right)
        #expect(editing.segments.map(\.reading) == ["きょうは", "よいて", "んき"])
        #expect(editing.reading == "きょうはよいてんき")
    }
}
