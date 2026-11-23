import Foundation
import Testing
@testable import MyIMELiveConversion

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
        let weather = try #require(typed("kyouhatennkigaii", in: engine))
        #expect(weather.candidates.contains("今日は天気がいい"))
    }
}
