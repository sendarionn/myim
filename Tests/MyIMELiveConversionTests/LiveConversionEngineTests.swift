import Foundation
import Testing
@testable import MyIMELiveConversion
import MyIMECore

/// Uses the dictionary SwiftPM checked out with the converter
@Suite(.serialized)
struct LiveConversionEngineTests {
    private static let dictionaryURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent(".build/checkouts/AzooKeyKanaKanjiConverter/Sources/KanaKanjiConverterModuleWithDefaultDictionary/azooKey_dictionary_storage/Dictionary")

    private func typed(_ letters: String, in engine: LiveConversionEngine) -> LiveConversionResult? {
        engine.reset()
        var result: LiveConversionResult?
        // A letter at a time, as the converter expects
        for end in 1...letters.count {
            result = engine.convert(romaji: String(letters.prefix(end))) ?? result
        }
        return result
    }

    @Test
    func aTypedSentenceIsConvertedAsAWhole() throws {
        try #require(FileManager.default.fileExists(atPath: Self.dictionaryURL.path))
        let engine = LiveConversionEngine(
            dictionaryURL: Self.dictionaryURL,
            workingDirectoryURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("myim-live-conversion-tests", isDirectory: true)
        )
        let meeting = try #require(typed("kaiginoshiryouwojunbishimasu", in: engine))
        #expect(meeting.reading == "かいぎのしりょうをじゅんびします")
        #expect(meeting.candidates.first == "会議の資料を準備します")
        // Not always first without the neural model, but offered
        let weather = try #require(typed("kyouhatenkigaii", in: engine))
        #expect(weather.candidates.contains("今日は天気がいい"))
    }

    /// Hyphens are long vowels and punctuation is Japanese after romaji,
    /// as in ordinary conversion; numbers keep their symbols
    @Test
    func longVowelsAndPunctuationReadAsInOrdinaryConversion() throws {
        try #require(FileManager.default.fileExists(atPath: Self.dictionaryURL.path))
        let engine = LiveConversionEngine(
            dictionaryURL: Self.dictionaryURL,
            workingDirectoryURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("myim-live-conversion-tests", isDirectory: true)
        )
        #expect(try #require(typed("ko-hi-", in: engine)).candidates.first == "コーヒー")
        #expect(try #require(typed("su-pa-", in: engine)).candidates.first == "スーパー")
        let sentence = try #require(typed("ekimaenoko-hi-sutandode,ko-hi-wokatta.", in: engine))
        #expect(sentence.reading == "えきまえのこーひーすたんどで、こーひーをかった。")
        #expect(sentence.candidates.contains("駅前のコーヒースタンドで、コーヒーを買った。"))
        #expect(try #require(typed("3.14", in: engine)).reading == "3.14")
    }

    /// Capitals, digits and symbols among the letters leave the rest
    /// converted
    @Test
    func mixedLettersDigitsAndSymbolsAreConverted() throws {
        try #require(FileManager.default.fileExists(atPath: Self.dictionaryURL.path))
        let engine = LiveConversionEngine(
            dictionaryURL: Self.dictionaryURL,
            workingDirectoryURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("myim-live-conversion-tests", isDirectory: true)
        )
        let capital = try #require(typed("Kyou", in: engine))
        #expect(capital.status == .converted)
        #expect(capital.candidates.contains("今日"))
        let year = try #require(typed("nihon2026nenn", in: engine))
        #expect(year.status == .converted)
        #expect(year.candidates.contains("日本2026年"))
        let mark = try #require(typed("kyou!tenki", in: engine))
        #expect(mark.status == .converted)
        #expect(mark.candidates.contains("今日!天気"))
        let product = try #require(typed("iPhone,wokatta", in: engine))
        #expect(product.status == .converted)
        #expect(product.candidates.first?.hasPrefix("iPhone,") == true)
        #expect(try #require(typed("3.14", in: engine)).candidates.first == "3.14")
        #expect(try #require(typed("example.com", in: engine)).status != .converted
            || typed("example.com", in: engine)?.candidates.first == "example.com")
    }

    /// The converter reads ん as ordinary conversion does, typed a letter at
    /// a time
    @Test
    func nBeforeNaRowReadsAsInOrdinaryConversion() throws {
        try #require(FileManager.default.fileExists(atPath: Self.dictionaryURL.path))
        let engine = LiveConversionEngine(
            dictionaryURL: Self.dictionaryURL,
            workingDirectoryURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("myim-live-conversion-tests", isDirectory: true)
        )
        for keys in ["konna", "kanno", "henkanno", "raibuhenkanno", "raibuhenkannno", "kan'no", "kann"] {
            let result = try #require(typed(keys, in: engine))
            #expect(result.reading == RomajiConverter().hiragana(from: keys), "\(keys)")
            #expect(result.status == LiveConversionInput.Reading.converted, "\(keys)")
        }
    }
}
