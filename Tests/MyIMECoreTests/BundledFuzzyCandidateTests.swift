import Foundation
import Testing
@testable import MyIMECore

/// Runs the "もしかして" pipeline with the bundled dictionaries and an
/// imported SKK layer that contains abbrev headwords such as `hs` and `tom`
@Suite(.serialized)
struct BundledFuzzyCandidateTests {
    private struct Fixture: Sendable {
        let entries: [DictionaryEntry]
        let basic: ConversionEngine
        let system: IndexedDictionaryEngine
        let conjugations: VerbConjugationDictionary
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
              let verbText = try? String(
                contentsOf: resources.appendingPathComponent(
                    "mozc-verb-classes.tsv"
                ),
                encoding: .utf8
              ),
              let system = try? IndexedDictionaryEngine(
                contentsOf: resources.appendingPathComponent("mozc-dictionary.tsv")
              ) else {
            return nil
        }
        let conjugations = VerbConjugationDictionary(text: verbText)
        let repository = FuzzyEngineRepository()
        repository.prepare(
            for: entries + VerbInflectionCandidateGenerator.typoSearchEntries(
                from: entries,
                conjugations: conjugations
            )
        )
        return Fixture(
            entries: entries,
            basic: ConversionEngine(entries: entries),
            system: system,
            conjugations: conjugations,
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
        let fuzzyCandidates = try await fuzzyCandidates(for: query)

        #expect(fuzzyCandidates.first == expected)
    }

    @Test(arguments: [
        ("saihshin", ["際ハッシウム品", "再ハッシウム品"]),
        ("gyouka", ["魚羽化", "ギョ羽化"]),
        ("matomte", ["魔トム手", "マトム手"])
    ])
    func doesNotGenerateSplitDictionaryCompounds(
        query: String,
        fragments: [String]
    ) async throws {
        let fuzzyCandidates = try await fuzzyCandidates(for: query)
        let page = fuzzyCandidates.prefix(4)

        #expect(fragments.allSatisfy { !page.contains($0) })
    }

    @Test
    func keepsCompoundVerbInStandardCandidatesWithoutMechanicalSplits()
        async throws {
        let fixture = try #require(Self.fixture)
        let standard = StandardConversionCandidateSource(
            userEngine: LayeredConversionEngine(engines: []),
            importedEngine: Self.importedSKK,
            basicEngine: fixture.basic,
            symbolEngine: ConversionEngine(entries: []),
            systemEngine: fixture.system,
            verbInflectionGenerator: VerbInflectionCandidateGenerator(
                entries: fixture.entries
            ),
            verbConjugations: fixture.conjugations
        ).candidates(for: .init(
            input: "yobaretemo",
            conversionReading: "yobaretemo"
        )).map(\.storageText)
        let fuzzy = try await fuzzyCandidates(for: "yobaretemo")

        #expect(standard.contains("呼ばれても"))
        #expect(!fuzzy.contains("世場レテ藻"))
        #expect(!fuzzy.contains("世場レテ喪"))
    }

    @Test(arguments: [
        ("kaigii", "会議"),
        ("denwq", "電話"),
        ("keisna", "計算"),
        ("benkuo", "勉強"),
        ("tegmai", "手紙")
    ])
    func handlesOtherSingleCharacterTypos(query: String, expected: String) async throws {
        let fuzzyCandidates = try await fuzzyCandidates(for: query)

        #expect(fuzzyCandidates.prefix(4).contains(expected))
    }

    @Test
    func findsDatabaseFromMultipleRomajiErrors() async throws {
        let fuzzyCandidates = try await fuzzyCandidates(for: "de-tsb-su")

        #expect(fuzzyCandidates.prefix(4).contains("データベース"))
    }

    @Test
    func findsDatabaseFromNearbyNumberAndSymbolKeys() async throws {
        let fuzzyCandidates = try await fuzzyCandidates(for: "de=tab0su")

        #expect(fuzzyCandidates.prefix(3).contains("データベース"))
    }

    /// InputController searches with the resolved reading and excludes the
    /// standard candidates, which the typo leaves empty
    @Test(arguments: ["de=tab0su", "de-tsb-su"])
    func suggestsDatabaseWhenTheTypoLeavesNoStandardCandidate(
        input: String
    ) async throws {
        let fixture = try #require(Self.fixture)
        let reading = ConversionReadingResolver.resolve(input)
        let standard = StandardConversionCandidateSource(
            userEngine: LayeredConversionEngine(engines: []),
            importedEngine: Self.importedSKK,
            basicEngine: fixture.basic,
            symbolEngine: ConversionEngine(entries: []),
            systemEngine: fixture.system,
            verbInflectionGenerator: VerbInflectionCandidateGenerator(
                entries: []
            )
        ).candidates(for: .init(input: input, conversionReading: reading))

        let fuzzyCandidates = try await fuzzyCandidates(
            for: reading,
            visibleCandidates: Set(standard.map(\.storageText))
        )

        #expect(reading == input)
        #expect(standard.isEmpty)
        #expect(fuzzyCandidates.prefix(4).contains("データベース"))
    }

    @Test(arguments: ["de=tab0su", "de-tsb-su"])
    func learnedExactInputKeepsDatabaseFuzzyCandidateWithoutDuplicatingIt(
        input: String
    ) async throws {
        let fixture = try #require(Self.fixture)
        let learned = try #require(UnselectedInputLearningPolicy.entry(
            originalInput: input,
            hasSelectedCandidate: false
        ))
        let learnedEntry = DictionaryEntry(
            reading: learned.reading,
            candidates: [learned.candidate]
        )
        let userDictionary = LayeredConversionEngine(engines: [
            ConversionEngine(entries: [learnedEntry])
        ])
        let repository = FuzzyEngineRepository()
        repository.prepare(
            baseEntries: fixture.entries
                + VerbInflectionCandidateGenerator.typoSearchEntries(
                    from: fixture.entries,
                    conjugations: fixture.conjugations
                ),
            baseKey: "learned-exact-input-test",
            userEntries: [learnedEntry]
        )
        let standard = StandardConversionCandidateSource(
            userEngine: userDictionary,
            importedEngine: Self.importedSKK,
            basicEngine: fixture.basic,
            symbolEngine: ConversionEngine(entries: []),
            systemEngine: fixture.system,
            verbInflectionGenerator: VerbInflectionCandidateGenerator(
                entries: []
            )
        ).candidates(for: .init(input: input, conversionReading: input))
        let source = FuzzyCandidateSource(
            query: input,
            visibleCandidates: Set(standard.map(\.storageText)),
            userDictionary: userDictionary,
            importedDictionary: Self.importedSKK,
            basicDictionary: fixture.basic,
            mozcDictionary: fixture.system,
            fuzzyRepository: repository
        )
        let fuzzyCandidates = await source.matchTiers()
            .flatMap { $0 }
            .flatMap(\.candidates)

        #expect(standard.map(\.storageText).contains(input))
        #expect(fuzzyCandidates.contains("データベース"))
        #expect(!fuzzyCandidates.contains(input))
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

    /// `=`, `+`, and `_` sit on or beside the `-` key on the US layout,
    /// so the whole input is searched and the long vowel restored
    @Test(arguments: [
        ("a=to", "アート"), ("a_to", "アート"), ("a+to", "アート"),
        ("de=tab0su", "データベース"), ("de_tab0su", "データベース")
    ])
    func correctsSymbolsAroundTheLongVowelKey(
        input: String,
        expected: String
    ) async throws {
        let query = FuzzyQueryResolver.resolve(
            input: input,
            conversionReading: ConversionReadingResolver.resolve(input)
        )
        let fuzzyCandidates = try await fuzzyCandidates(for: query)

        #expect(query == input)
        #expect(fuzzyCandidates.prefix(3).contains(expected))
    }

    /// Symbols typed on purpose keep the reading before them, and nothing
    /// is suggested from the symbol alone
    @Test(arguments: ["a=b", "foo=bar", "x+y"])
    func doesNotCorrectIntendedSymbols(input: String) async throws {
        let reading = ConversionReadingResolver.resolve(input)
        let query = FuzzyQueryResolver.resolve(
            input: input,
            conversionReading: reading
        )
        let fuzzyCandidates = try await fuzzyCandidates(for: input)

        #expect(query == reading)
        #expect(fuzzyCandidates.isEmpty)
    }

    private func fuzzyCandidates(
        for query: String,
        visibleCandidates: Set<String> = []
    ) async throws -> [String] {
        let fixture = try #require(Self.fixture)
        let source = FuzzyCandidateSource(
            query: query,
            visibleCandidates: visibleCandidates,
            userDictionary: LayeredConversionEngine(engines: []),
            importedDictionary: Self.importedSKK,
            basicDictionary: fixture.basic,
            mozcDictionary: fixture.system,
            fuzzyRepository: fixture.repository
        )
        var session = FuzzyCandidateSession()
        session.replace(
            matchTiers: await source.matchTiers(),
            recencyRanks: [:]
        )
        return session.candidates.map(\.storageText)
    }
}
