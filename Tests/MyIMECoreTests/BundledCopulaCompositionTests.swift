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

    /// Nouns Mozc marks as taking する conjugate as する verbs, from the
    /// typed romaji to the first page of the candidate panel, without any
    /// selection history
    @Test(arguments: [
        ("kirokushi", "記録し"), ("kirokushite", "記録して"),
        ("kirokushita", "記録した"), ("kirokushimasu", "記録します"),
        ("kirokusuru", "記録する"), ("kirokushimashita", "記録しました"),
        ("kirokushinai", "記録しない"), ("kirokushimasen", "記録しません"),
        ("kirokusureba", "記録すれば"), ("kirokushiyou", "記録しよう"),
        ("kirokushiro", "記録しろ"), ("kirokuseyo", "記録せよ"),
        ("kakuninshi", "確認し"), ("kakuninsuru", "確認する"),
        ("benkyoushite", "勉強して"), ("kenkyuushita", "研究した"),
        ("setsumeishimasu", "説明します"), ("setteisuru", "設定する"),
        ("sousashite", "操作して")
    ])
    func showsSuruNounConjugationsOnTheFirstPage(
        input: String,
        expected: String
    ) throws {
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

        #expect(session.candidateTexts.prefix(4).contains(expected))
        #expect(Set(session.candidateTexts).count
            == session.candidateTexts.count)
    }

    /// 机 and 林檎 are not nouns that take する; りんごした itself is only
    /// the hiragana of the input
    @Test(arguments: [
        ("gakuseshi", "学生し"), ("tsukueshite", "机して"),
        ("ringoshita", "林檎した")
    ])
    func doesNotConjugateNounsThatDoNotTakeSuru(
        input: String,
        unexpected: String
    ) throws {
        let source = try #require(Self.source)
        let candidates = source.candidates(for: .init(
            input: input,
            conversionReading: ConversionReadingResolver.resolve(input)
        )).map(\.storageText)

        #expect(!candidates.contains(unexpected))
    }

    /// Ordinary words ending like a form of する keep their first candidate
    @Test(arguments: [
        ("watashi", "私"), ("ashita", "明日"), ("kesshite", "決して"),
        ("toshite", "として"), ("kashi", "菓子"), ("kaishi", "開始")
    ])
    func keepsTheFirstCandidateOfOrdinaryWords(
        input: String,
        expected: String
    ) throws {
        let source = try #require(Self.source)
        let candidates = source.candidates(for: .init(
            input: input,
            conversionReading: ConversionReadingResolver.resolve(input)
        )).map(\.storageText)

        #expect(candidates.first == expected)
    }

    /// Mirrors InputController from the typed romaji to the candidate
    /// panel: the reading is resolved, the standard candidates generated,
    /// and the panel state filled; the composition is on the first page
    @Test(arguments: [
        ("kireina", "綺麗な"), ("benrina", "便利な"), ("shizukana", "静かな"),
        ("yuumeina", "有名な"), ("kantanna", "簡単な"), ("kireini", "綺麗に"),
        ("benrini", "便利に"), ("gakuseitoshite", "学生として"),
        ("kyoushitoshiteno", "教師としての"), ("watashinitotte", "私にとって"),
        ("kenkyuunitsuite", "研究について")
    ])
    func showsCompositionsOnTheFirstPageFromTypedRomaji(
        input: String,
        expected: String
    ) throws {
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

        #expect(session.candidateTexts.prefix(4).contains(expected))
    }

    /// 学生 is a noun, not a na-adjective stem
    @Test
    func doesNotShowNaAfterANounFromTypedRomaji() throws {
        let source = try #require(Self.source)
        let candidates = source.candidates(for: .init(
            input: "gakuseina",
            conversionReading: ConversionReadingResolver.resolve("gakuseina")
        )).map(\.storageText)

        #expect(!candidates.contains("学生な"))
    }

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
