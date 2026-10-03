import Foundation
import Testing
@testable import MyIMECore

/// Uses the bundled Mozc dictionary with the generated person name hints
@Suite(.serialized)
struct BundledPersonNameRankingTests {
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
              ),
              let hints = try? String(
                contentsOf: resources.appendingPathComponent(
                    "mozc-person-name-hints.tsv"
                ),
                encoding: .utf8
              ) else {
            return nil
        }
        return StandardConversionCandidateSource(
            userEngine: LayeredConversionEngine(engines: []),
            importedEngine: LayeredConversionEngine(engines: []),
            basicEngine: ConversionEngine(entries: basicEntries),
            symbolEngine: ConversionEngine(entries: []),
            systemEngine: systemEngine,
            verbInflectionGenerator: VerbInflectionCandidateGenerator(
                entries: basicEntries
            ),
            deferredSystemCandidates: DeferredSystemCandidates(text: hints)
        )
    }()

    @Test(arguments: [
        ("tugino", "次の"),
        ("tsugino", "次の"),
        ("imino", "意味の")
    ])
    func ranksTheStemAndParticleAboveARarePersonName(
        input: String,
        expected: String
    ) throws {
        #expect(try candidates(for: input).first == expected)
    }

    @Test(arguments: [
        ("tanaka", "田中"),
        ("sano", "佐野"),
        ("yoshino", "吉野"),
        ("ueno", "上野")
    ])
    func keepsCommonPersonAndPlaceNamesFirst(
        input: String,
        expected: String
    ) throws {
        #expect(try candidates(for: input).first == expected)
    }

    @Test
    func keepsCommonSurnamesInPlace() throws {
        #expect(try candidates(for: "satou").prefix(3).contains("佐藤"))
        #expect(try candidates(for: "kono").prefix(4).contains("小野"))
    }

    private func candidates(for input: String) throws -> [String] {
        let source = try #require(Self.source)
        return source.candidates(for: .init(
            input: input,
            conversionReading: input
        )).map(\.storageText)
    }
}
