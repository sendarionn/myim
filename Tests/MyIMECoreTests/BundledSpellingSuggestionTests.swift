import Foundation
import Testing
@testable import MyIMECore

/// Runs the "もしかして" pipeline with the bundled dictionaries and an
/// imported SKK layer that contains abbrev headwords such as `hs` and `tom`
@Suite(.serialized)
struct BundledSpellingSuggestionTests {
    private struct Fixture: Sendable {
        let basic: ConversionEngine
        let system: IndexedDictionaryEngine
        let compound: CompoundDictionaryCandidateGenerator
        let repository: FuzzyEngineRepository
    }

    private static let fixture: Fixture? = {
        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyIMEMacOS/Resources")
        guard let text = try? String(
                contentsOf: resources.appendingPathComponent("basic-dictionary.tsv"),
                encoding: .utf8
              ),
              let entries = try? DictionaryParser().parse(text),
              let system = try? IndexedDictionaryEngine(
                contentsOf: resources.appendingPathComponent("mozc-dictionary.tsv")
              ) else {
            return nil
        }
        let repository = FuzzyEngineRepository()
        repository.prepare(
            for: entries + VerbInflectionCandidateGenerator.typoSearchEntries(
                from: entries
            )
        )
        return Fixture(
            basic: ConversionEngine(entries: entries),
            system: system,
            compound: CompoundDictionaryCandidateGenerator(entries: entries),
            repository: repository
        )
    }()

    private static let importedSKK = LayeredConversionEngine(engines: [
        ConversionEngine(entries: [
            DictionaryEntry(reading: "hs", candidates: ["ハッシウム"]),
            DictionaryEntry(reading: "tom", candidates: ["トム"]),
            DictionaryEntry(reading: "ma", candidates: ["Massachusetts"]),
            DictionaryEntry(reading: "さい", candidates: ["際"]),
            DictionaryEntry(reading: "ま", candidates: ["魔"]),
            DictionaryEntry(reading: "ぎょ", candidates: ["魚"]),
            DictionaryEntry(reading: "うか", candidates: ["羽化"])
        ])
    ])

    @Test(arguments: [
        ("saihshin", "最新"),
        ("gyouka", "評価"),
        ("matomte", "まとめて")
    ])
    func ranksTheCorrectedReadingFirst(query: String, expected: String) async throws {
        let suggestions = try await suggestions(for: query)

        #expect(suggestions.first == expected)
    }

    @Test(arguments: [
        ("saihshin", ["際ハッシウム品", "再ハッシウム品"]),
        ("gyouka", ["魚羽化", "ギョ羽化"]),
        ("matomte", ["魔トム手", "マトム手"])
    ])
    func splitCompoundsDoNotOutrankTheCorrection(
        query: String,
        fragments: [String]
    ) async throws {
        let suggestions = try await suggestions(for: query)
        let page = suggestions.prefix(4)

        #expect(fragments.allSatisfy { !page.contains($0) })
    }

    @Test(arguments: [
        ("kaigii", "会議"),
        ("denwq", "電話"),
        ("keisna", "計算"),
        ("benkuo", "勉強"),
        ("tegmai", "手紙")
    ])
    func handlesOtherSingleCharacterTypos(query: String, expected: String) async throws {
        let suggestions = try await suggestions(for: query)

        #expect(suggestions.prefix(4).contains(expected))
    }

    @Test
    func findsDatabaseFromMultipleRomajiErrors() async throws {
        let suggestions = try await suggestions(for: "de-tsb-su")

        #expect(suggestions.prefix(4).contains("データベース"))
    }

    @Test
    func findsDatabaseFromNearbyNumberAndSymbolKeys() async throws {
        let suggestions = try await suggestions(for: "de=tab0su")

        #expect(suggestions.prefix(3).contains("データベース"))
    }

    /// InputController searches with the resolved reading and excludes the
    /// normal candidates, which the typo leaves empty
    @Test(arguments: ["de=tab0su", "de-tsb-su"])
    func suggestsDatabaseWhenTheTypoLeavesNoNormalCandidate(
        input: String
    ) async throws {
        let fixture = try #require(Self.fixture)
        let reading = ConversionReadingResolver.resolve(input)
        let normal = StandardConversionCandidateSource(
            userEngine: LayeredConversionEngine(engines: []),
            importedEngine: Self.importedSKK,
            basicEngine: fixture.basic,
            symbolEngine: ConversionEngine(entries: []),
            systemEngine: fixture.system,
            verbInflectionGenerator: VerbInflectionCandidateGenerator(
                entries: []
            )
        ).candidates(for: .init(input: input, conversionReading: reading))

        let suggestions = try await suggestions(
            for: reading,
            visibleCandidates: Set(normal.map(\.storageText))
        )

        #expect(reading == input)
        #expect(normal.isEmpty)
        #expect(suggestions.prefix(4).contains("データベース"))
    }

    @Test(arguments: [
        ("10=", "10="),
        ("2026nen", "2026nen"),
        ("de=", "de"),
        ("kana", "kana")
    ])
    func keepsTheReadingOfOrdinaryDigitAndSymbolInput(
        input: String,
        reading: String
    ) {
        #expect(ConversionReadingResolver.resolve(input) == reading)
    }

    private func suggestions(
        for query: String,
        visibleCandidates: Set<String> = []
    ) async throws -> [String] {
        let fixture = try #require(Self.fixture)
        let source = FuzzySuggestionSource(
            query: query,
            visibleCandidates: visibleCandidates,
            userDictionary: LayeredConversionEngine(engines: []),
            importedDictionary: Self.importedSKK,
            basicDictionary: fixture.basic,
            mozcDictionary: fixture.system,
            compoundGenerator: fixture.compound,
            fuzzyRepository: fixture.repository
        )
        var coordinator = FuzzySuggestionCoordinator()
        coordinator.replace(
            matchTiers: await source.matchTiers(),
            recencyRanks: [:]
        )
        return coordinator.suggestions.map(\.candidate)
    }
}
