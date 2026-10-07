import Foundation
import Testing
@testable import MyIMECore

@Suite(.serialized)
struct BundledLongVowelCandidateTests {
    private static let systemDictionary: IndexedDictionaryEngine? = {
        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyIMEMacOS/Resources")
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

    private func makeSource() throws -> StandardConversionCandidateSource {
        StandardConversionCandidateSource(
            userEngine: LayeredConversionEngine(engines: []),
            importedEngine: LayeredConversionEngine(engines: []),
            basicEngine: ConversionEngine(entries: []),
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
