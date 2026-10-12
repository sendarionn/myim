import Foundation
import Testing
@testable import MyIMECore

@Suite(.serialized)
struct BundledLongVowelCandidateTests {
    private static let resources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/MyIMEMacOS/Resources")

    private static let basicEntries: [DictionaryEntry]? = {
        guard let text = try? String(
            contentsOf: resources.appendingPathComponent("basic-dictionary.tsv"),
            encoding: .utf8
        ) else {
            return nil
        }
        return try? DictionaryParser().parse(text)
    }()

    private static let systemDictionary: IndexedDictionaryEngine? = {
        return try? IndexedDictionaryEngine(
            contentsOf: resources.appendingPathComponent("mozc-dictionary.tsv")
        )
    }()

    @Test
    func typedLongVowelDoesNotExposeUnrelatedBundledReading() throws {
        let source = try makeSource()

        #expect(visibleCandidates(source, input: "byu-").contains("ビュー"))
        #expect(!visibleCandidates(source, input: "byu-").contains("別府"))
        #expect(visibleCandidates(source, input: "beppu").contains("別府"))
    }

    @Test
    func bundledDictionaryKeepsLongVowelsDistinct() throws {
        let entries = try #require(Self.basicEntries)
        let engine = ConversionEngine(entries: entries)

        #expect(engine.candidates(for: "yu-za-").contains("ユーザー"))
        #expect(engine.candidates(for: "de-ta").contains("データ"))
        #expect(engine.candidates(for: "ki-").contains("キー"))
        #expect(engine.candidates(for: "ko-hi-").contains("コーヒー"))
        #expect(engine.candidates(for: "fairu").contains("ファイル"))
        #expect(engine.candidates(for: "kii").contains("奇異"))
        #expect(engine.candidates(for: "kouho").contains("候補"))
        #expect(!engine.candidates(for: "ki-").contains("奇異"))
        #expect(!engine.candidates(for: "kii").contains("キー"))
    }

    @Test
    func bundledDictionaryBuildsLongVowelCompounds() throws {
        let entries = try #require(Self.basicEntries)
        let generator = CompoundDictionaryCandidateGenerator(entries: entries)

        #expect(generator.candidates(for: "yu-za-jisho").contains("ユーザー辞書"))
        #expect(
            ConversionEngine(entries: entries)
                .candidates(for: "de-tabe-su")
                .contains("データベース")
        )
    }

    @Test
    func fuzzySourceDisplaysBundledLongVowelCompound() async throws {
        let entries = try #require(Self.basicEntries)
        let repository = FuzzyEngineRepository()
        repository.prepare(for: entries)
        let source = FuzzyCandidateSource(
            query: "yu-za-jisho",
            visibleCandidates: [],
            userDictionary: LayeredConversionEngine(engines: []),
            basicDictionary: ConversionEngine(entries: entries),
            mozcDictionary: try #require(Self.systemDictionary),
            compoundGenerator: CompoundDictionaryCandidateGenerator(
                entries: entries
            ),
            fuzzyRepository: repository
        )

        let candidates = await source.matchTiers()
            .flatMap { $0 }
            .flatMap(\.candidates)

        #expect(candidates.contains("ユーザー辞書"))
    }

    private func makeSource() throws -> StandardConversionCandidateSource {
        let basicEntries = try #require(Self.basicEntries)
        return StandardConversionCandidateSource(
            userEngine: LayeredConversionEngine(engines: []),
            importedEngine: LayeredConversionEngine(engines: []),
            basicEngine: ConversionEngine(entries: basicEntries),
            symbolEngine: ConversionEngine(entries: []),
            systemEngine: try #require(Self.systemDictionary),
            verbInflectionGenerator: VerbInflectionCandidateGenerator(entries: [])
        )
    }

    private func visibleCandidates(
        _ source: StandardConversionCandidateSource,
        input: String
    ) -> [String] {
        var session = CandidateSession()
        session.replace(
            with: source.candidates(for: .init(
                input: input,
                conversionReading: input
            )),
            input: input,
            reading: input
        )
        return session.candidateTexts
    }
}
