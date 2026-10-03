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
