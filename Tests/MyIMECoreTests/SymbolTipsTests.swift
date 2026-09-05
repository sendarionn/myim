import Testing
@testable import MyIMECore

@Suite
struct SymbolTipsTests {
    @Test func describesProlongedSoundMark() {
        let tips = SymbolTips.make(for: "ー")
        #expect(tips?.codePoint == "U+30FC")
        #expect(tips?.unicodeName == "KATAKANA-HIRAGANA PROLONGED SOUND MARK")
    }

    @Test func describesRawSlashInput() {
        let tips = SymbolTips.make(for: "/")
        #expect(tips?.codePoint == "U+002F")
        #expect(tips?.unicodeName == "SOLIDUS")
    }

    @Test func ignoresOrdinaryWords() {
        #expect(SymbolTips.make(for: "候補") == nil)
        #expect(SymbolTips.make(for: "あ") == nil)
    }
}
