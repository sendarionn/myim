import Testing
@testable import MyIMECore

@Suite
struct LiveConversionInputTests {
    private func read(_ typed: String) -> String {
        LiveConversionInput.elements(for: typed).map(\.text).joined()
    }

    @Test
    func hyphensAfterRomajiAreLongVowels() {
        #expect(read("ko-hi-") == "ko" + "ー" + "hi" + "ー")
        #expect(read("su-pa-sutando") == "su" + "ー" + "pa" + "ー" + "sutando")
    }

    @Test
    func commasAndPeriodsAfterRomajiArePunctuation() {
        #expect(read("watashiha,kyoumo") == "watashiha、kyoumo")
        #expect(read("ame.") == "ame。")
        #expect(read("ko-hi-.") == "ko" + "ー" + "hi" + "ー。")
    }

    @Test
    func numbersAndOtherWordsKeepTheirSymbols() {
        #expect(read("3.14") == "3.14")
        #expect(read("1,000") == "1,000")
        #expect(read("example.com") == "example.com")
        #expect(read("1-2") == "1-2")
    }

    @Test
    func aReadingWithLettersLeftInsideIsNotAConversion() {
        #expect(LiveConversionInput.reading("こーひー") == .converted)
        #expect(LiveConversionInput.reading("かk") == .typingRomaji)
        #expect(LiveConversionInput.reading("えぁmpぇ.こm") == .notRomaji)
    }

    @Test
    func onlyLettersAreReadAsRomaji() {
        let elements = LiveConversionInput.elements(for: "ko-")
        #expect(elements.map(\.isRomaji) == [true, true, false])
    }
}
