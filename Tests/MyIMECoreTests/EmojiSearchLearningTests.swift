import Foundation
import Testing
@testable import MyIMECore

/// A search chosen from the conversion candidates in the emoji panel is
/// learned like a commit of that candidate
@Suite
struct EmojiSearchLearningTests {
    @Test
    func confirmingAChosenCandidateIsLearnedOnce() {
        var learning = EmojiSearchLearning()

        let learned1 = learning.learns(confirming: "丸", choseCandidate: true)
        #expect(learned1)
        // Escape back to editing and confirming again is the same search
        let learned2 = learning.learns(confirming: "丸", choseCandidate: true)
        #expect(!learned2)
    }

    @Test
    func changingTheSearchAllowsLearningAgain() {
        var learning = EmojiSearchLearning()
        _ = learning.learns(confirming: "丸", choseCandidate: true)

        learning.searchChanged(to: "丸い")
        learning.searchChanged(to: "丸")

        let learned3 = learning.learns(confirming: "丸", choseCandidate: true)
        #expect(learned3)
        let learned4 = learning.learns(confirming: "猫", choseCandidate: true)
        #expect(learned4)
    }

    @Test
    func keepingTheSameSearchDoesNotRelearnIt() {
        var learning = EmojiSearchLearning()
        _ = learning.learns(confirming: "丸", choseCandidate: true)

        learning.searchChanged(to: "丸")

        let learned5 = learning.learns(confirming: "丸", choseCandidate: true)
        #expect(!learned5)
    }

    @Test(arguments: ["", "  "])
    func emptySearchIsNotLearned(_ searchText: String) {
        var learning = EmojiSearchLearning()

        let learned6 = learning.learns(confirming: searchText, choseCandidate: true)
        #expect(!learned6)
    }

    @Test
    func typedTextWithoutAChosenCandidateIsNotLearned() {
        var learning = EmojiSearchLearning()

        let learned7 = learning.learns(confirming: "maru", choseCandidate: false)
        #expect(!learned7)
    }

    @Test
    func reopeningThePanelStartsAnewSearch() {
        var learning = EmojiSearchLearning()
        _ = learning.learns(confirming: "丸", choseCandidate: true)

        learning.reset()

        let learned8 = learning.learns(confirming: "丸", choseCandidate: true)
        #expect(learned8)
    }

    /// The learned candidate reaches the ordinary candidates of its reading
    @Test
    func learnedSearchIsOfferedFirstForItsReading() throws {
        let source = StandardConversionCandidateSource(
            userEngine: LayeredConversionEngine(engines: []),
            importedEngine: LayeredConversionEngine(engines: []),
            basicEngine: ConversionEngine(entries: [
                DictionaryEntry(reading: "maru", candidates: ["円", "丸", "〇"])
            ]),
            symbolEngine: ConversionEngine(entries: []),
            systemEngine: IndexedDictionaryEngine(),
            verbInflectionGenerator: VerbInflectionCandidateGenerator(entries: [])
        )
        func first(_ history: CandidateSelectionHistory) -> String? {
            source.candidates(for: .init(
                input: "maru",
                conversionReading: "maru",
                selectionHistory: history
            )).first?.storageText
        }
        var history = CandidateSelectionHistory()
        #expect(first(history) == "円")

        // As the input controller records a committed candidate
        history.record(
            "丸",
            readings: CandidateSelectionReading.historyReadings(
                for: CandidateSelectionReading.resolve(
                    conversionReading: "maru",
                    originalInput: "maru"
                )
            )
        )
        let restored = try JSONDecoder().decode(
            CandidateSelectionHistory.self,
            from: JSONEncoder().encode(history)
        )

        #expect(first(restored) == "丸")
    }
}
