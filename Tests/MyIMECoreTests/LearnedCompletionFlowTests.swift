import Foundation
import Testing
@testable import MyIMECore

/// A candidate committed once is offered again while its reading is still
/// being typed, through the same learning and candidate paths as typing
@Suite(.serialized)
struct LearnedCompletionFlowTests {
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
        try? IndexedDictionaryEngine(
            contentsOf: resources.appendingPathComponent("mozc-dictionary.tsv")
        )
    }()

    @Test
    func committedKatakanaCompletesFromAPartialReading() throws {
        let typing = try Typing()
        #expect(!typing.candidates(for: "hottope").contains("ホットペッパー"))

        try typing.commit("ホットペッパー", typed: "hottopeppa-")

        for input in ["hottope", "hottopep", "hottopeppa"] {
            #expect(typing.candidates(for: input).contains("ホットペッパー"))
        }
        #expect(typing.candidates(for: "hottopeppa-").contains("ホットペッパー"))
    }

    @Test
    func completionSurvivesSavingAndReloading() throws {
        let typing = try Typing()
        try typing.commit("ホットペッパー", typed: "hottopeppa-")

        try typing.restart()

        #expect(typing.candidates(for: "hottope").contains("ホットペッパー"))
    }

    @Test
    func dictionaryKatakanaCompletesFromAPartialReading() throws {
        let typing = try Typing()

        try typing.commit("コーヒー", typed: "ko-hi-")

        #expect(typing.candidates(for: "ko-h").contains("コーヒー"))
    }

    @Test
    func kanjiAndEnglishCompletionsAreKept() throws {
        let typing = try Typing()

        try typing.commit("開発", typed: "kaihatsu")
        try typing.commit("Smartlock", typed: "smartlock")

        #expect(typing.candidates(for: "kaihat").contains("開発"))
        #expect(typing.candidates(for: "smartl").contains("Smartlock"))
    }

    @Test
    func candidateRemovedFromTheHistoryIsNotCompleted() throws {
        let typing = try Typing()
        try typing.commit("ホットペッパー", typed: "hottopeppa-")

        typing.store.remove(["ホットペッパー"])

        #expect(!typing.candidates(for: "hottope").contains("ホットペッパー"))
    }

    /// Typing with the bundled dictionaries and a history saved to disk
    private final class Typing {
        private let source: StandardConversionCandidateSource
        private let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("candidate-selection-history.json")
        private(set) var store: CandidateSelectionHistoryStore

        init() throws {
            source = StandardConversionCandidateSource(
                userEngine: LayeredConversionEngine(engines: []),
                importedEngine: LayeredConversionEngine(engines: []),
                basicEngine: ConversionEngine(
                    entries: try #require(LearnedCompletionFlowTests.basicEntries)
                ),
                symbolEngine: ConversionEngine(entries: []),
                systemEngine: try #require(
                    LearnedCompletionFlowTests.systemDictionary
                ),
                verbInflectionGenerator: VerbInflectionCandidateGenerator(
                    entries: []
                )
            )
            store = CandidateSelectionHistoryStore(
                history: CandidateSelectionHistory(),
                writer: Self.writer(for: fileURL)
            )
        }

        /// The candidates shown for `input`, in panel order
        func candidates(for input: String) -> [String] {
            let reading = ConversionReadingResolver.resolve(input)
            var session = CandidateSession()
            session.replace(
                with: source.candidates(for: .init(
                    input: input,
                    conversionReading: reading,
                    selectionHistory: store.snapshot
                )),
                input: input,
                reading: reading
            )
            return session.candidateTexts
        }

        /// Selects `candidate` among those shown for `input` and learns it
        /// under the keys the input controller uses
        func commit(_ candidate: String, typed input: String) throws {
            try #require(candidates(for: input).contains(candidate))
            let reading = CandidateSelectionReading.resolve(
                conversionReading: ConversionReadingResolver.resolve(input),
                originalInput: input
            )
            store.record(
                candidate,
                readings: CandidateSelectionReading.historyReadings(for: reading)
            )
        }

        /// Saves the history and loads it again, as a restart does
        func restart() throws {
            store.flush()
            store = CandidateSelectionHistoryStore(
                history: try JSONDecoder().decode(
                    CandidateSelectionHistory.self,
                    from: Data(contentsOf: fileURL)
                ),
                writer: Self.writer(for: fileURL)
            )
        }

        private static func writer(
            for fileURL: URL
        ) -> DeferredJSONFileWriter<CandidateSelectionHistory> {
            DeferredJSONFileWriter(
                fileURL: fileURL,
                delay: 60,
                queueLabel: "myim.learned-completion-flow-test"
            )
        }
    }
}
