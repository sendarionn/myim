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

    /// Romaji is read in lower case, as ordinary conversion reads it, and
    /// the letters keep their case where they are not romaji
    @Test
    func capitalsAreReadAsRomaji() {
        #expect(read("Kyou") == "kyou")
        #expect(read("KYOUHA") == "kyouha")
        #expect(LiveConversionInput.elements(for: "iPhonewo")
            == [.init(text: "iPhonewo", isRomaji: false)])
    }

    /// A word that is not romaji is kept as typed, and the reading around
    /// it is still converted
    @Test
    func wordsThatAreNotRomajiAreKeptAsTyped() {
        let elements = LiveConversionInput.elements(for: "example.com!kyou")
        #expect(elements.first == .init(text: "example", isRomaji: false))
        #expect(LiveConversionInput.reading("example.com!きょう", elements: elements) == .converted)
        #expect(LiveConversionInput.reading("iPhoneをかった", elements: [
            .init(text: "iPhone", isRomaji: false)
        ]) == .converted)
    }

    /// An n before a digit or symbol is ん, which the converter would leave
    /// waiting for the letter after it
    @Test
    func anNBeforeWhatIsNotALetterIsMoraic() {
        #expect(read("nihon2026") == "nihonn2026")
        #expect(read("nihonn2026") == "nihonn2026")
        #expect(read("kyou!tenki") == "kyou!tenki")
    }

    @Test
    func onlyLettersAreReadAsRomaji() {
        let elements = LiveConversionInput.elements(for: "ko-")
        #expect(elements.map(\.isRomaji) == [true, true, false])
    }
}
