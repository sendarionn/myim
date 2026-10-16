import Foundation
import Testing
@testable import MyIMECore

/// `desu` and `deshita` typed after a word convert the whole input, as
/// particles such as `ha` do
@Suite(.serialized)
struct BundledCopulaCompositionTests {
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
              let verbs = try? String(
                contentsOf: resources.appendingPathComponent("mozc-verb-classes.tsv"),
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
            verbConjugations: VerbConjugationDictionary(text: verbs)
        )
    }()

    @Test(arguments: [
        ("kouhodesu", "候補です"),
        ("kouhodeshita", "候補でした"),
        ("gakuseidesu", "学生です"),
        ("gakuseideshita", "学生でした"),
        ("benridesu", "便利です"),
        ("benrideshita", "便利でした"),
        ("utsukushiidesu", "美しいです")
    ])
    func convertsWordsFollowedByTheCopula(
        input: String,
        expected: String
    ) throws {
        let candidates = try visible(input)

        #expect(candidates.prefix(4).contains(expected))
        #expect(candidates.count == Set(candidates).count)
    }

    @Test(arguments: [
        ("kouho", "候補"),
        ("kouhoha", "候補は"),
        ("kouhoga", "候補が")
    ])
    func keepsWordsAndParticles(input: String, expected: String) throws {
        #expect(try visible(input).prefix(4).contains(expected))
    }

    @Test
    func verbsAreNotJoinedToTheCopula() throws {
        #expect(try !visible("ikudesu").contains("行くです"))
        #expect(try !visible("taberudesu").contains("食べるです"))
        #expect(try !visible("utsukushiideshita").contains("美しいでした"))
    }

    @Test(arguments: ["kouhodes", "kouhode", "desu", "deshita"])
    func incompleteOrStemlessEndingsAreNotJoined(_ input: String) throws {
        let joined = try visible(input).filter {
            $0.hasSuffix("です") || $0.hasSuffix("でした")
        }

        #expect(joined.allSatisfy { $0 == "です" || $0 == "でした" })
    }

    @Test
    func compositionIsCommittedAsTheWholeInput() throws {
        let source = try #require(Self.source)
        let candidate = try #require(source.candidates(for: .init(
            input: "kouhodesu",
            conversionReading: "kouhodesu"
        )).first { $0.storageText == "候補です" })

        #expect(candidate.hasSource(.particleComposition))
        #expect(candidate.commitText == "候補です")
    }

    private func visible(_ input: String) throws -> [String] {
        let source = try #require(Self.source)
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
