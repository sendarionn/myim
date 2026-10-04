import Foundation
import Testing
@testable import MyIMECore

@Suite(.serialized)
struct BundledParticleCompositionTests {
    private static let source: StandardConversionCandidateSource? = {
        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyIMEMacOS/Resources")
        guard let basicText = try? String(
                contentsOf: resources.appendingPathComponent("basic-dictionary.tsv"),
                encoding: .utf8
              ),
              let basicEntries = try? DictionaryParser().parse(basicText),
              let systemEngine = try? IndexedDictionaryEngine(
                contentsOf: resources.appendingPathComponent("mozc-dictionary.tsv")
              ) else {
            return nil
        }
        let userDictionary = ConversionEngine(entries: [])
        // SKK-JISYO.L contains abbrev headwords such as `made /メイド/メード/`
        let importedSKK = ConversionEngine(entries: [
            DictionaryEntry(reading: "made", candidates: ["メイド", "メード"]),
            DictionaryEntry(reading: "まで", candidates: ["迄"])
        ])
        return StandardConversionCandidateSource(
            userEngine: LayeredConversionEngine(engines: [userDictionary]),
            importedEngine: LayeredConversionEngine(engines: [importedSKK]),
            basicEngine: ConversionEngine(entries: basicEntries),
            symbolEngine: ConversionEngine(entries: []),
            systemEngine: systemEngine,
            verbInflectionGenerator: VerbInflectionCandidateGenerator(
                entries: basicEntries
            )
        )
    }()

    @Test(arguments: [
        ("made", "まで"),
        ("madeha", "までは"),
        ("kamerade", "カメラで"),
        ("pasokonwo", "パソコンを"),
        ("amerikano", "アメリカの"),
        ("kouhowo", "候補を"),
        ("kouhonite", "候補にて"),
        ("kouhonitsuki", "候補につき"),
        ("kouhoniyotte", "候補によって")
    ])
    func ranksTheNaturalReadingFirst(input: String, expected: String) throws {
        let source = try #require(Self.source)

        let candidates = source.candidates(for: .init(
            input: input,
            conversionReading: input
        )).map(\.storageText)

        #expect(candidates.first == expected)
    }

    @Test
    func doesNotSplitAnAbbrevHeadwordBeforeAParticle() throws {
        let source = try #require(Self.source)

        let candidates = source.candidates(for: .init(
            input: "madeha",
            conversionReading: "madeha"
        )).map(\.storageText)

        #expect(!candidates.contains("メイドは"))
        #expect(!candidates.contains("メードは"))
    }

    @Test
    func doesNotGenerateNounPlusVerbTeForm() throws {
        let source = try #require(Self.source)

        let candidates = source.candidates(for: .init(
            input: "shiteite",
            conversionReading: "shiteite"
        )).map(\.storageText)

        #expect(!candidates.contains("指定て"))
        #expect(candidates.contains("していて"))
    }
}
