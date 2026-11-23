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

    /// A selection inside kanji widens to the phrase, since the kanji
    /// cannot be told apart in the reading; kana written as they read
    /// can be selected alone
    @Test
    func aSelectionConvertsTheKanaItReads() throws {
        var editing = phrases()
        // 天 of 転機
        editing.moveCursor(by: -1)
        editing.extendSelection(by: -1)
        #expect(try #require(editing.conversionTarget).reading == "てんき")
        #expect(try #require(editing.conversionTarget).range == 5..<7)
        // は of 今日は; the first arrow ends the selection
        editing.moveCursor(by: -1)
        editing.moveCursor(by: -10)
        editing.moveCursor(by: 2)
        editing.extendSelection(by: 1)
        #expect(try #require(editing.conversionTarget).reading == "は")
        #expect(try #require(editing.conversionTarget).range == 2..<3)
    }

    /// Only the selection changes, and the rest keeps its text and reading
    @Test
    func aConversionReplacesOnlyTheSelection() {
        var editing = phrases()
        editing.moveCursor(by: -1)
        editing.extendSelection(by: -1)
        editing.replaceSelection(with: "天気", keepsSelected: true)
        #expect(editing.text == "今日は良い天気")
        #expect(editing.selection == 5..<7)
        editing.replaceSelection(with: "てんき")
        #expect(editing.text == "今日は良いてんき")
        #expect(editing.reading == "きょうはよいてんき")
        #expect(editing.selection == nil)
        #expect(editing.cursor == 8)
        // Part of a phrase in kana
        editing.moveCursor(by: -10)
        editing.moveCursor(by: 2)
        editing.extendSelection(by: 1)
        editing.replaceSelection(with: "葉")
        #expect(editing.text == "今日葉良いてんき")
        #expect(editing.segments.map(\.reading) == ["きょう", "は", "よい", "てんき"])
    }
}
