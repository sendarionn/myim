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
              ),
              let adjectives = try? String(
                contentsOf: resources.appendingPathComponent(
                    "mozc-adjective-classes.tsv"
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
            verbConjugations: VerbConjugationDictionary(text: verbs)
                .addingSuruVerbs(from: basicEntries),
            adjectiveDictionary: JapaneseAdjectiveDictionary(text: adjectives)
        )
    }()

    @Test(arguments: [
        ("kouhodesu", "候補です"),
        ("kouhodeshita", "候補でした"),
        ("gakuseidesu", "学生です"),
        ("gakuseideshita", "学生でした"),
        ("benridesu", "便利です"),
        ("benrideshita", "便利でした"),
        ("utsukushiidesu", "美しいです"),
        ("kouhoda", "候補だ"),
        ("kouhodatta", "候補だった"),
        ("kouhodearu", "候補である"),
        ("kouhodeatta", "候補であった"),
        ("kouhodehanai", "候補ではない"),
        ("kouhojanai", "候補じゃない"),
        ("kouhodehanakatta", "候補ではなかった"),
        ("kouhodehaarimasen", "候補ではありません"),
        ("kouhodeshou", "候補でしょう"),
        ("kouhodarou", "候補だろう"),
        ("kouhodesuka", "候補ですか"),
        ("kouhodayone", "候補だよね"),
        ("kouhonara", "候補なら"),
        ("kouhodeareba", "候補であれば"),
        ("kouhodattara", "候補だったら"),
        ("kouhokamoshirenai", "候補かもしれない"),
        ("kouhodearukamoshirenai", "候補であるかもしれない"),
        ("kouhodearubeki", "候補であるべき"),
        ("kouhonohazuda", "候補のはずだ"),
        ("benridatta", "便利だった")
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
        #expect(try !visible("utsukushiida").contains("美しいだ"))
        #expect(try !visible("taberudearu").contains("食べるである"))
        #expect(try !visible("kouhoshiyou").contains("候補しよう"))
        #expect(try !visible("kouhoshitai").contains("候補したい"))
    }

    @Test(arguments: [
        ("benrina", "便利な"),
        ("kireina", "綺麗な"),
        ("sugoina", "すごいな"),
        ("gakuseitoshite", "学生として"),
        ("kyoushitoshiteno", "教師としての"),
        ("watashinitotte", "私にとって"),
        ("riyoushanitotte", "利用者にとって"),
        ("kenkyuunitsuite", "研究について"),
        ("nihonnitsuite", "日本について")
    ])
    func generatesGrammaticalConnectionsFromBundledWordClasses(
        input: String,
        expected: String
    ) throws {
        let compositions = try #require(Self.source).candidates(for: .init(
            input: input,
            conversionReading: input
        )).filter { $0.hasSource(.particleComposition) }

        #expect(compositions.contains { $0.storageText == expected })
    }

    @Test(arguments: [
        "gakuseina", "ikuna", "taberuna", "benritoshite"
    ])
    func suppressesConnectionsRejectedByBundledWordClasses(
        input: String
    ) throws {
        let compositions = try #require(Self.source).candidates(for: .init(
            input: input,
            conversionReading: input
        )).filter { $0.hasSource(.particleComposition) }

        #expect(compositions.isEmpty)
    }

    @Test(arguments: ["kouhodes", "kouhode", "desu", "deshita"])
    func incompleteOrStemlessEndingsAreNotJoined(_ input: String) throws {
        let joined = try visible(input).filter {
            $0.hasSuffix("です") || $0.hasSuffix("でした")
        }

        #expect(joined.allSatisfy { $0 == "です" || $0 == "でした" })
    }

    /// Readings such as `fuda` are words of their own rather than a short
    /// word followed by だ
    @Test(arguments: ["fuda", "kuda", "inada"])
    func shortWordsDoNotTakeDa(_ input: String) throws {
        let source = try #require(Self.source)
        let composed = source.candidates(for: .init(
            input: input,
            conversionReading: input
        )).filter { $0.hasSource(.particleComposition) }

        #expect(!composed.contains { $0.storageText.hasSuffix("だ") })
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
