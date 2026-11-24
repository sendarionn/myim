import Foundation
import Testing
@testable import MyIMECore

@Suite
struct LiveConversionPhrasesTests {
    private func phrases() -> LiveConversionPreview {
        LiveConversionPreview(segments: LiveConversionSegment.phrases(of: [
            .init(surface: "今日", reading: "きょう"),
            .init(surface: "は", reading: "は"),
            .init(surface: "良い", reading: "よい"),
            .init(surface: "転機", reading: "てんき")
        ], functionWords: [false, true, false, false]))
    }

    @Test
    func kanaAtTheStartOfAWordGoesWithTheWordBefore() {
        let phrases = LiveConversionSegment.phrases(of: [
            .init(surface: "強", reading: "きょう"),
            .init(surface: "は良い", reading: "はよい"),
            .init(surface: "天気", reading: "てんき"),
            .init(surface: "コーヒー", reading: "こーひー"),
            .init(surface: "を飲む", reading: "をのむ")
        ], functionWords: [false, true, false, false, true])
        #expect(phrases.map(\.surface) == ["強は", "良い", "天気", "コーヒーを", "飲む"])
        #expect(phrases.map(\.reading) == ["きょうは", "よい", "てんき", "こーひーを", "のむ"])
    }

    /// The converter's 今日は|いい天気: いい is no particle and is split
    /// from 天気, not given to 今日は; お茶 stays whole
    @Test
    func kanaStartingAWordThatIsNoParticleStaysApart() {
        let phrases = LiveConversionSegment.phrases(of: [
            .init(surface: "今日は", reading: "きょうは"),
            .init(surface: "いい天気", reading: "いいてんき"),
            .init(surface: "お茶", reading: "おちゃ")
        ], functionWords: [false, false, false])
        #expect(phrases.map(\.surface) == ["今日は", "いい", "天気", "お茶"])
    }

    @Test
    func kanaWordsGoWithTheWordBefore() {
        #expect(phrases().segments.map(\.surface) == ["今日は", "良い", "転機"])
        #expect(phrases().reading == "きょうはよいてんき")
    }

    /// Letters kept as typed, which the converter gives a character at a
    /// time, stay one phrase
    @Test
    func lettersKeptAsTypedAreOnePhrase() {
        let words: [LiveConversionSegment] = "iPhone".map { .init(surface: String($0), reading: String($0)) }
            + [.init(surface: "を買った", reading: "をかった")]
        let phrases = LiveConversionSegment.phrases(
            of: words,
            functionWords: Array(repeating: false, count: 6) + [true]
        )
        #expect(phrases.map(\.surface) == ["iPhoneを", "買った"])
    }

    /// The arrows move a cursor from the end, and Shift with them selects
    /// from it as in a text field
    @Test
    func theArrowsMoveACursorAndShiftSelects() {
        var editing = phrases()
        #expect(editing.cursor == 7)
        #expect(editing.selection == nil)
        editing.moveCursor(by: -1)
        editing.moveCursor(by: -1)
        #expect(editing.cursor == 5)
        #expect(editing.selection == nil)
        editing.extendSelection(by: -1)
        editing.extendSelection(by: -1)
        #expect(editing.selection == 3..<5)
        #expect(editing.selectedTextRange == NSRange(location: 3, length: 2))
        editing.extendSelection(by: 1)
        #expect(editing.selection == 4..<5)
        // Without Shift the selection ends at the side moved to
        editing.moveCursor(by: -1)
        #expect(editing.selection == nil)
        #expect(editing.cursor == 4)
    }

    /// Only what is selected is converted again: kana written as they read,
    /// katakana among them, are matched in the reading, kanji where the
    /// converter takes the kana each side to them, and a selection whose
    /// reading cannot be told is not converted rather than widened
    @Test
    func aSelectionConvertsExactlyTheKanaItReads() throws {
        var editing = LiveConversionPreview(segments: [
            .init(surface: "ローマ字として", reading: "ろーまじとして"),
            .init(surface: "今日", reading: "きょう"),
            .init(surface: "天気", reading: "てんき")
        ])
        // ローマ
        editing.moveCursor(by: -12)
        editing.extendSelection(by: 3)
        let roma = try #require(editing.conversionTarget())
        #expect(roma.reading == "ろーま")
        #expect(roma.range == 0..<3)
        // 字
        editing.moveCursor(by: 1)
        editing.extendSelection(by: 1)
        #expect(try #require(editing.conversionTarget()).reading == "じ")
        // 気 of 天気, confirmed by the converter
        let converts: (String, String) -> Bool = { reading, surface in
            ["てん": "天", "き": "気"][reading] == surface
        }
        editing.moveCursor(by: 1)
        editing.moveCursor(by: 20)
        editing.extendSelection(by: -1)
        #expect(editing.selection == 10..<11)
        #expect(editing.conversionTarget() == nil)
        #expect(try #require(editing.conversionTarget(converts: converts)).reading == "き")
        // 日 of 今日 reads no part of きょう alone
        editing.moveCursor(by: -1)
        editing.moveCursor(by: -1)
        editing.extendSelection(by: -1)
        #expect(String(Array(editing.text)[editing.selection!]) == "日")
        #expect(editing.conversionTarget(converts: converts) == nil)
        #expect(editing.selection != nil)
    }

    /// The conversions listed and the one taken replace the same part, and
    /// the text before and after it is kept whatever their length
    @Test
    func aConversionReplacesOnlyTheSelection() throws {
        var editing = LiveConversionPreview(segments: [
            .init(surface: "ローマ字として", reading: "ろーまじとして"),
            .init(surface: "使う", reading: "つかう")
        ])
        editing.moveCursor(by: -9)
        editing.extendSelection(by: 3)
        let target = try #require(editing.conversionTarget())
        let shown = editing.replacing(target, with: "ろうま", keepsSelected: true)
        #expect(shown.text == "ろうま字として使う")
        #expect(shown.selection == 0..<3)
        let longer = editing.replacing(target, with: "羅馬帝国", keepsSelected: true)
        #expect(longer.text == "羅馬帝国字として使う")
        #expect(longer.selection == 0..<4)
        let taken = editing.replacing(target, with: "ローマ")
        #expect(taken.text == "ローマ字として使う")
        #expect(taken.reading == "ろーまじとしてつかう")
        #expect(taken.selection == nil)
        #expect(taken.cursor == 3)
        #expect(taken.segments.map(\.reading) == ["ろーま", "じとして", "つかう"])
    }
}
