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
        )
    }()

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
