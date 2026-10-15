import Foundation
import Testing
@testable import MyIMECore

/// An emoji committed from search results is registered under the letters
/// typed for the search, and offered by ordinary conversion afterwards
@Suite
struct EmojiSearchRegistrationTests {
    @Test(arguments: [
        ("neko", "neko"), ("arigatou", "arigatou"), ("Egao", "egao")
    ])
    func registersTheTypedLetters(typed: String, expected: String) {
        #expect(EmojiSearchRegistration.reading(
            typedInput: typed,
            conversionReading: ConversionReadingResolver.resolve(typed)
                .lowercased(),
            isRecentEmoji: false
        ) == expected)
    }

    @Test
    func searchEditedBeforeCommittingUsesTheFinalLetters() {
        // nekoo shortened back to neko before the emoji is committed
        #expect(EmojiSearchRegistration.reading(
            typedInput: "neko",
            conversionReading: "neko",
            isRecentEmoji: false
        ) == "neko")
    }

    @Test(arguments: ["", "  "])
    func emptySearchRegistersNothing(_ typed: String) {
        #expect(EmojiSearchRegistration.reading(
            typedInput: typed,
            conversionReading: "",
            isRecentEmoji: false
        ) == nil)
    }

    @Test
    func recentEmojiRegistersNothing() {
        #expect(EmojiSearchRegistration.reading(
            typedInput: "",
            conversionReading: "",
            isRecentEmoji: true
        ) == nil)
    }

    @Test
    func committedEmojiIsOfferedForTheTypedLetters() throws {
        let learned = try Learned()

        try learned.commit("🐈", typed: "neko")

        #expect(learned.candidates(for: "neko").contains("🐈"))
        #expect(learned.dictionary.entries.flatMap(\.candidates) == ["🐈"])
    }

    @Test
    func repeatedCommitsKeepOneEntryAndRefreshTheHistory() throws {
        let learned = try Learned()

        try learned.commit("🐈", typed: "neko")
        try learned.commit("🐱", typed: "neko")
        #expect(learned.candidates(for: "neko").firstIndex(of: "🐱")!
            < learned.candidates(for: "neko").firstIndex(of: "🐈")!)
        try learned.commit("🐈", typed: "neko")

        #expect(learned.dictionary.entries.flatMap(\.candidates) == ["🐈", "🐱"])
        #expect(learned.candidates(for: "neko").firstIndex(of: "🐈")!
            < learned.candidates(for: "neko").firstIndex(of: "🐱")!)
    }

    @Test
    func oneEmojiCanBeRegisteredForSeveralInputs() throws {
        let learned = try Learned()

        try learned.commit("😊", typed: "egao")
        try learned.commit("😊", typed: "nikoniko")

        #expect(learned.candidates(for: "egao").contains("😊"))
        #expect(learned.candidates(for: "nikoniko").contains("😊"))
    }

    @Test
    func registrationSurvivesARestart() throws {
        let learned = try Learned()
        try learned.commit("⭕", typed: "maru")

        let restarted = try learned.restarted()

        #expect(restarted.candidates(for: "maru").contains("⭕"))
    }

    @Test
    func manualEntryIsKept() throws {
        let learned = try Learned(entries: [
            DictionaryEntry(reading: "neko", candidates: ["猫", "🐈"])
        ])

        try learned.commit("🐈", typed: "neko")

        #expect(learned.dictionary.entries.flatMap(\.candidates) == ["猫", "🐈"])
    }

    @Test
    func deletedEmojiIsRegisteredAgainOnTheNextCommit() throws {
        let learned = try Learned()
        try learned.commit("🐈", typed: "neko")

        // ⌘X on the candidate removes the entry and its history
        try learned.dictionary.remove(candidate: "🐈")
        learned.history.remove(["🐈"])
        #expect(!learned.candidates(for: "neko").contains("🐈"))

        try learned.commit("🐈", typed: "neko")
        #expect(learned.candidates(for: "neko").contains("🐈"))
    }

    /// The user dictionary and selection history the input controller
    /// writes when an emoji is committed from a search
    private final class Learned {
        let dictionary: UserDictionaryStore
        let history: CandidateSelectionHistoryStore
        /// The dictionary text last saved, as the input controller writes it
        private let savedDictionary: () -> String
        private let historyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("candidate-selection-history.json")
        private let historyWriter: DeferredJSONFileWriter<CandidateSelectionHistory>

        init(
            entries: [DictionaryEntry] = [],
            history: CandidateSelectionHistory = CandidateSelectionHistory()
        ) throws {
            var saved = ""
            dictionary = UserDictionaryStore(entries: entries) {
                saved = DictionarySerializer.text(from: $0)
            }
            historyWriter = DeferredJSONFileWriter(
                fileURL: historyURL,
                delay: 60,
                queueLabel: "myim.emoji-search-registration-test"
            )
            self.history = CandidateSelectionHistoryStore(
                history: history,
                writer: historyWriter
            )
            savedDictionary = { saved }
        }

        func commit(_ emoji: String, typed: String) throws {
            let reading = try #require(EmojiSearchRegistration.reading(
                typedInput: typed,
                conversionReading: ConversionReadingResolver.resolve(typed),
                isRecentEmoji: false
            ))
            try dictionary.add(reading: reading, candidate: emoji)
            history.record(
                emoji,
                readings: CandidateSelectionReading.historyReadings(
                    for: reading
                )
            )
        }

        func candidates(for input: String) -> [String] {
            StandardConversionCandidateSource(
                userEngine: LayeredConversionEngine(engines: [
                    ConversionEngine(entries: dictionary.entries)
                ]),
                importedEngine: LayeredConversionEngine(engines: []),
                basicEngine: ConversionEngine(entries: []),
                symbolEngine: ConversionEngine(entries: []),
                systemEngine: IndexedDictionaryEngine(),
                verbInflectionGenerator: VerbInflectionCandidateGenerator(
                    entries: []
                )
            ).candidates(for: .init(
                input: input,
                conversionReading: input,
                selectionHistory: history.snapshot
            )).map(\.storageText)
        }

        func restarted() throws -> Learned {
            history.flush()
            return try Learned(
                entries: DictionaryParser().parse(savedDictionary()),
                history: JSONDecoder().decode(
                    CandidateSelectionHistory.self,
                    from: Data(contentsOf: historyURL)
                )
            )
        }
    }
}
