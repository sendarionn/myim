import Foundation
import Testing
@testable import MyIMECore

/// Dictionaries key 順位 as `jun'i`, while `juni` reads じゅに; exact words
/// for the `n` read as ん follow those of the reading as typed
@Suite(.serialized)
struct BundledMoraicNCandidateTests {
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
        return StandardConversionCandidateSource(
            userEngine: LayeredConversionEngine(engines: []),
            importedEngine: LayeredConversionEngine(engines: []),
            basicEngine: ConversionEngine(entries: basicEntries),
            symbolEngine: ConversionEngine(entries: []),
            systemEngine: systemEngine,
            verbInflectionGenerator: VerbInflectionCandidateGenerator(
                entries: basicEntries
            )
        )
    }()

    @Test(arguments: [
        ("juni", "順位"),
        ("tani", "単位"),
        ("genin", "原因"),
        ("konin", "婚姻"),
        ("kinen", "禁煙")
    ])
    func nBetweenVowelsAlsoReadsAsMoraicN(
        input: String,
        expected: String
    ) throws {
        #expect(try visible(input).contains(expected))
    }

    @Test
    func readingAsTypedKeepsItsWordsFirst() throws {
        let candidates = try visible("juni")

        #expect(candidates.first == "ジュニ")
        #expect(candidates.firstIndex(of: "順位")! < 4)
        #expect(try visible("tani").first == "谷")
        #expect(try visible("junni").first == "順に")
        #expect(try visible("jun'i").first == "順位")
    }

    @Test
    func exactWordsComeBeforeCompositions() throws {
        let source = try #require(Self.source)
        let candidates = source.candidates(for: .init(
            input: "juni",
            conversionReading: "juni"
        ))
        let lastExact = try #require(candidates.lastIndex {
            $0.storageText == "順位" || $0.storageText == "ジュニ"
        })
        let firstComposition = try #require(candidates.firstIndex {
            $0.hasSource(.particleComposition)
        })

        #expect(lastExact < firstComposition)
    }

    @Test
    func compositionsAndPrefixesKeepTheReadingAsTyped() throws {
        #expect(try !visible("nanimo").contains("何位も"))
        #expect(try !visible("shinaru").contains("新アルバム"))
    }

    @Test
    func chosenWordComesFirstNextTime() throws {
        let source = try #require(Self.source)
        var history = CandidateSelectionHistory()
        history.record(
            "順位",
            readings: CandidateSelectionReading.historyReadings(for: "juni")
        )

        let candidates = source.candidates(for: .init(
            input: "juni",
            conversionReading: "juni",
            selectionHistory: history
        ))

        #expect(candidates.first?.storageText == "順位")
    }

    @Test(arguments: [
        ("juni", ["jun'i"]),
        ("nani", ["nan'i"]),
        ("genin", ["gen'in"]),
        ("junni", []),
        ("tanni", []),
        ("kanyuu", []),
        ("na", [])
    ])
    func moraicNReadingsAreAddedOnlyBetweenVowels(
        input: String,
        expected: [String]
    ) {
        #expect(RomajiCanonicalizer.moraicNBeforeVowelLookupInputs(
            from: input
        ) == expected)
        #expect(!RomajiCanonicalizer.dictionaryLookupInputs(from: input)
            .contains { expected.contains($0) })
    }

    private func visible(_ input: String) throws -> [String] {
        let source = try #require(Self.source)
        let reading = ConversionReadingResolver.resolve(input)
        var session = CandidateSession()
        session.replace(
            with: source.candidates(for: .init(
                input: input,
                conversionReading: reading
            )),
            input: input,
            reading: reading
        )
        return session.candidateTexts
    }
}
