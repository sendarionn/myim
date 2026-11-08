import Foundation
import Testing
@testable import MyIMECore

/// Converts verbs with the bundled dictionaries and `mozc-verb-classes.tsv`
@Suite(.serialized)
struct BundledVerbConjugationTests {
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
                .addingSuruVerbs(from: basicEntries)
        )
    }()

    /// 続ける after the 連用形 of each class, then conjugated as the
    /// ichidan verb it is
    /// A verb joined after the 連用形 conjugates as that verb: 終わる and
    /// 直す as godan verbs, 始める and 終える as ichidan verbs
    @Test(arguments: [
        ("shiowaru", "し終わる"), ("shiowatta", "し終わった"),
        ("shiowaranai", "し終わらない"), ("yomioeru", "読み終える"),
        ("yomioemashita", "読み終えました"), ("shihajimeru", "し始める"),
        ("shihajimeta", "し始めた"), ("shihajimeteiru", "し始めている"),
        ("shinaosu", "し直す"), ("shinaoshita", "し直した"),
        ("shinaosanai", "し直さない"), ("benkyoushinaosu", "勉強し直す"),
        ("tsukaikiru", "使い切る"), ("tsukaikitta", "使い切った"),
        ("shiwasureta", "し忘れた"), ("yomikakeru", "読みかける"),
        ("shisugiru", "し過ぎる"), ("hashiridasu", "走り出す"),
        ("kakikomu", "書き込む"), ("tasukeau", "助け合う"),
        ("yarinuku", "やり抜く"), ("kakiageru", "書き上げる")
    ])
    func joinsCompoundVerbs(input: String, expected: String) throws {
        let source = try #require(Self.source)
        let candidates = source.candidates(for: .init(
            input: input,
            conversionReading: input
        )).map(\.storageText)

        #expect(candidates.first == expected)
    }

    /// Rare kanji of the same reading, kana verbs other than する, and
    /// する before verbs that read like other words give no compound
    @Test(arguments: [
        ("mikiru", "観切る"), ("mikakeru", "診かける"),
        ("hanashiau", "離し合う"), ("ukeau", "ウケ合う"),
        ("shiageru", "し上げる"), ("tsukaikiru", "遣い切る")
    ])
    func leavesOutUnnaturalCompounds(input: String, unexpected: String)
        throws {
        let source = try #require(Self.source)
        let candidates = source.candidates(for: .init(
            input: input,
            conversionReading: input
        )).map(\.storageText)

        #expect(!candidates.contains(unexpected))
    }

    /// Everyday words ending like a joined verb keep their first candidate
    @Test(arguments: [
        ("ikiru", "生きる"), ("dekiru", "できる"), ("okiru", "起きる"),
        ("deau", "出会う"), ("dekakeru", "出かける"), ("omoidasu", "思い出す")
    ])
    func keepsEverydayWordsFirst(input: String, expected: String) throws {
        let source = try #require(Self.source)
        let candidates = source.candidates(for: .init(
            input: input,
            conversionReading: input
        )).map(\.storageText)

        #expect(candidates.first == expected)
    }

    @Test(arguments: [
        ("shitsuzukeru", "し続ける"), ("shitsuzuketa", "し続けた"),
        ("shitsuzukenai", "し続けない"), ("shitsuzuketeiru", "し続けている"),
        ("tsukaitsuzukeru", "使い続ける"), ("tsukaitsuzuketa", "使い続けた"),
        ("yomitsuzukeru", "読み続ける"),
        ("kakitsuzuketeiru", "書き続けている"),
        ("tabetsuzukeru", "食べ続ける"),
        ("benkyoushitsuzukeru", "勉強し続ける"),
        ("kirokushitsuzuketa", "記録し続けた"),
        ("tsukaitsuzukemasu", "使い続けます"),
        ("tsukaitsuzukemashita", "使い続けました"),
        ("tsukaitsuzukenakatta", "使い続けなかった"),
        ("tsukaitsuzuketai", "使い続けたい"),
        ("tsukaitsuzukeyou", "使い続けよう"),
        ("tsukaitsuzukereba", "使い続ければ"),
        ("kitsuzukeru", "来続ける")
    ])
    func continuesTheVerbWithTsuzukeru(input: String, expected: String)
        throws {
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

        #expect(session.candidateTexts.prefix(4).contains(expected))
    }

    /// Kana verbs other than する give no 続ける form; the kana candidate
    /// covers them
    @Test
    func continuesOnlyKanjiVerbsAndSuru() throws {
        let source = try #require(Self.source)
        let candidates = source.candidates(for: .init(
            input: "iitsuzukeru",
            conversionReading: "iitsuzukeru"
        )).map(\.storageText)

        #expect(candidates.first == "言い続ける")
        #expect(!candidates.contains("いい続ける"))
    }

    @Test(arguments: [
        ("wakatteiru", "分かっている"),
        ("shiritai", "知りたい"),
        ("tabeteiru", "食べている"),
        ("yondeiru", "読んでいる"),
        ("hanashitai", "話したい"),
        ("wakaranai", "分からない"),
        ("shitteiru", "知っている")
    ])
    func ranksTheConjugatedVerbFirst(input: String, expected: String) throws {
        #expect(try candidates(for: input).first == expected)
    }

    @Test(arguments: [
        ("shiritakunai", "知りたくない"),
        ("shiritakunakatta", "知りたくなかった"),
        ("shiritakatta", "知りたかった"),
        ("shiritakute", "知りたくて"),
        ("shiritakereba", "知りたければ"),
        ("shiritakunaru", "知りたくなる"),
        ("shiritakunatta", "知りたくなった"),
        ("shiritakunaranai", "知りたくならない"),
        ("mitakunai", "見たくない"),
        ("mitakatta", "見たかった"),
        ("mitakunatta", "見たくなった"),
        ("kakitakunai", "書きたくない"),
        ("yomitakatta", "読みたかった"),
        ("ikitakunatta", "行きたくなった")
    ])
    func ranksDesireExpressionsBeforeAutomaticKana(
        input: String,
        expected: String
    ) throws {
        #expect(try candidates(for: input).first == expected)
    }

    @Test(arguments: [
        ("kaiteiru", "書いている"),
        ("oyoideiru", "泳いでいる"),
        ("matteiru", "待っている"),
        ("asondeiru", "遊んでいる"),
        ("shindeiru", "死んでいる"),
        ("totteiru", "取っている"),
        ("miteiru", "見ている"),
        ("kiteiru", "来ている"),
        ("itteiru", "行っている")
    ])
    func placesEachConjugationClassNearTheTop(
        input: String,
        expected: String
    ) throws {
        #expect(try candidates(for: input).prefix(3).contains(expected))
    }

    @Test
    func keepsRepresentativeTeFormCandidate() throws {
        #expect(try candidates(for: "ninjite").contains("任じて"))
    }

    @Test(arguments: [
        ("arimasu", "あります"),
        ("shite", "して")
    ])
    func promotesRepeatedlySelectedAutomaticKanaWithBundledDictionaries(
        input: String,
        expected: String
    ) throws {
        let source = try #require(Self.source)
        var history = CandidateSelectionHistory()
        history.record(expected, reading: input)
        history.record(expected, reading: input)

        let candidate = try #require(source.candidates(for: .init(
            input: input,
            conversionReading: input,
            selectionHistory: history
        )).first)

        #expect(candidate.storageText == expected)
        #expect(candidate.hasSource(.automaticKana))
        #expect(!candidate.hasSource(.selectionHistory))
    }

    @Test(arguments: [
        ("yobu", "呼ぶ"),
        ("yonde", "呼んで"),
        ("yobarete", "呼ばれて"),
        ("yobaretemo", "呼ばれても"),
        ("yobarenakatta", "呼ばれなかった"),
        ("yobaserareru", "呼ばせられる"),
        ("yobaseraretemo", "呼ばせられても"),
        ("wakatteitemo", "分かっていても")
    ])
    func generatesCompoundFormsFromBundledVerbData(
        input: String,
        expected: String
    ) throws {
        #expect(try candidates(for: input).contains(expected))
    }

    /// The potential of 買う reads like 変える; the ichidan verb's own forms
    /// stay first, kana verbs and rare variants give no potential
    @Test
    func potentialFormsStayBehindRealVerbs() throws {
        let source = try #require(Self.source)
        func candidates(_ input: String) -> [String] {
            source.candidates(for: .init(
                input: input,
                conversionReading: input
            )).map(\.storageText)
        }

        #expect(candidates("kaenai").first == "変えない")
        #expect(candidates("kaenai").contains("買えない"))
        #expect(candidates("kaeta").first == "変えた")
        #expect(candidates("ienai").first == "言えない")
        #expect(candidates("ienai").firstIndex(of: "いえない")
            ?? .max > 1)
        #expect(!candidates("kaerenai").contains("歸れない"))
        #expect(!candidates("nerenai").contains("寢れない"))
    }

    @Test(arguments: [
        ("tsukaenakunatta", "使えなくなった"),
        ("tsukaenakunaru", "使えなくなる"),
        ("tsukaenakunatte", "使えなくなって"),
        ("tsukaenakatta", "使えなかった"),
        ("tsukawanakunatta", "使わなくなった"),
        ("yomenakunatta", "読めなくなった"),
        ("kakenakunaru", "書けなくなる"),
        ("tabenakunatta", "食べなくなった")
    ])
    func showsNegativeStateChangesOnTheFirstPage(
        input: String,
        expected: String
    ) throws {
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

        #expect(session.candidateTexts.prefix(4).contains(expected))
    }

    @Test(arguments: [
        ("yobarete", "呼ばれて"),
        ("yobaretemo", "呼ばれても")
    ])
    func keepsCompoundFormsInCandidatePresentation(
        input: String,
        expected: String
    ) throws {
        let source = try #require(Self.source)
        let generated = source.candidates(for: .init(
            input: input,
            conversionReading: input
        ))
        var session = CandidateSession()

        session.replace(with: generated, input: input, reading: input)

        #expect(session.candidateTexts.contains(expected))
    }

    /// Re-conjugated passive and causative verbs reach the candidate panel
    @Test(arguments: [
        ("yobare", "呼ばれ"),
        ("yobarereba", "呼ばれれば"),
        ("yobaretemo", "呼ばれても"),
        ("yobarenakatta", "呼ばれなかった"),
        ("yobaremasendeshita", "呼ばれませんでした"),
        ("yobase", "呼ばせ"),
        ("yobaseru", "呼ばせる"),
        ("yobasereba", "呼ばせれば"),
        ("yobasareta", "呼ばされた"),
        ("yobasarenai", "呼ばされない"),
        ("yobaserarereba", "呼ばせられれば"),
        ("yondeiru", "呼んでいる"),
        ("yondeita", "呼んでいた"),
        ("yondeshimatta", "呼んでしまった"),
        ("yobeba", "呼べば"),
        ("tabereba", "食べれば"),
        ("kureba", "来れば"),
        ("ikeba", "行けば")
    ])
    func showsReconjugatedVerbsOnTheFirstPage(
        input: String,
        expected: String
    ) throws {
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

        #expect(session.candidateTexts.prefix(4).contains(expected))
    }

    /// Suru verbs listed in the basic dictionary and the volitional,
    /// obligation, and permission endings of every verb
    @Test(arguments: [
        ("kentoushiyou", "検討しよう"),
        ("kentoushimashou", "検討しましょう"),
        ("kentoushitai", "検討したい"),
        ("kentoushitakunai", "検討したくない"),
        ("kentoushinai", "検討しない"),
        ("kentoushinakatta", "検討しなかった"),
        ("kentoushiteiru", "検討している"),
        ("kentoushiteimasu", "検討しています"),
        ("kentoushitemiru", "検討してみる"),
        ("kentoushiteoku", "検討しておく"),
        ("kentoushitearu", "検討してある"),
        ("kentousubeki", "検討すべき"),
        ("kentoushinakerebanaranai", "検討しなければならない"),
        ("kentoushinakutemoii", "検討しなくてもいい"),
        ("kentoushitemoii", "検討してもいい"),
        ("kentoushitehanaranai", "検討してはならない"),
        ("tabeyou", "食べよう"),
        ("tabemashou", "食べましょう"),
        ("ikou", "行こう"),
        ("ikouka", "行こうか"),
        ("ikimashou", "行きましょう"),
        ("ikimasuka", "行きますか"),
        ("tabetakotogaaru", "食べたことがある"),
        ("tabeteshimatta", "食べてしまった")
    ])
    func showsSuruVerbsAndNewEndingsOnTheFirstPage(
        input: String,
        expected: String
    ) throws {
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

        #expect(session.candidateTexts.prefix(4).contains(expected))
    }

    @Test(arguments: [
        ("kagirazu", "限らず"),
        ("kagiranai", "限らない"),
        ("kagiranakatta", "限らなかった"),
        ("kagiranakereba", "限らなければ"),
        ("kagiranakute", "限らなくて"),
        ("kagiranaide", "限らないで"),
        ("kagirazuni", "限らずに"),
        ("kakazu", "書かず"),
        ("yomazu", "読まず"),
        ("tabezu", "食べず"),
        ("sezu", "せず"),
        ("kozu", "来ず"),
        ("kentousezu", "検討せず"),
        ("kagirimasen", "限りません"),
        ("kagirimasendeshita", "限りませんでした"),
        ("tabemasendeshita", "食べませんでした")
    ])
    func showsNegativeFormsOnTheFirstPage(
        input: String,
        expected: String
    ) throws {
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

        #expect(session.candidateTexts.prefix(4).contains(expected))
        #expect(!session.candidateTexts.contains("限りず"))
    }

    @Test
    func wordsEndingInZuKeepTheirDictionaryWordFirst() throws {
        #expect(try candidates(for: "mizu").first == "水")
        #expect(try candidates(for: "okazu").prefix(2).contains("おかず"))
    }

    @Test(arguments: [
        ("dassou", "脱そう"), ("gisou", "議そう"), ("hiyou", "干よう")
    ])
    func rareVerbsDoNotOfferTheVolitional(
        input: String,
        unexpected: String
    ) throws {
        #expect(try !candidates(for: input).contains(unexpected))
    }

    @Test
    func doesNotGenerateWrongConditionalForms() throws {
        #expect(try !candidates(for: "kakareba").contains("書かれば"))
        #expect(try !candidates(for: "taberareba").contains("食べられば"))
    }

    @Test
    func keepsNounsAndExactWordsAhead() throws {
        #expect(try candidates(for: "kitai").first == "期待")
        #expect(try candidates(for: "kaitai").first == "解体")
        #expect(try !candidates(for: "kite").contains("切て"))
        #expect(try !candidates(for: "satai").contains("去たい"))
        #expect(try !candidates(for: "kaeranai").contains("変えらない"))
    }

    private func candidates(for input: String) throws -> [String] {
        let source = try #require(Self.source)
        return source.candidates(for: .init(
            input: input,
            conversionReading: input
        )).map(\.storageText)
    }
}
