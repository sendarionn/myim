import Foundation
import Testing
@testable import MyIMECore

/// A phrase is learned exactly as it was inserted, including the spaces
/// between its commits, whichever way each commit was made
///
/// Each commit passes the units the input controller passes for that path
@Suite
struct NextInputSeparatorLearningTests {
    /// How `Smart` and the following space reach the learning store
    enum SpacePath: CaseIterable {
        /// Space while composing commits `Smart ` as one unit
        case spaceWhileComposing
        /// Return commits `Smart`, then Space goes to the app
        case spaceAfterCommit
        /// Space accepts `Smart` in the secondary panel
        case spaceOnSecondaryPanel
    }

    @Test(arguments: SpacePath.allCases)
    func spaceTypedBetweenCommitsIsLearned(path: SpacePath) {
        let typing = Typing()

        for _ in 0..<NextInputPredictionModel.minimumDirectSequenceCount {
            typing.commit("Smart", reading: "smart", then: " ", via: path)
            typing.commit("Inn", reading: "inn")
            typing.startNewLine()
        }

        let texts = typing.compounds(for: "sma").map(\.text)
        #expect(texts.contains("Smart Inn"))
        #expect(!texts.contains("SmartInn"))
    }

    @Test
    func nextInputCandidateSelectedAfterASpaceJoinsWithIt() {
        let typing = Typing()

        for _ in 0..<NextInputPredictionModel.minimumEpisodePromotionCount {
            typing.commit("Smart", reading: "smart", then: " ", via: .spaceAfterCommit)
            typing.select("Inn", reading: "inn", then: " ")
            typing.startNewLine()
        }

        #expect(typing.compounds(for: "sma").map(\.text) == ["Smart Inn"])
    }

    /// The space committing the last word separates it from what follows,
    /// as when it is typed after the commit
    @Test
    func spaceCommittingTheLastWordStaysOutOfThePhrase() {
        let typing = Typing()

        for _ in 0..<NextInputPredictionModel.minimumDirectSequenceCount {
            typing.commit("Smart", reading: "smart", then: " ", via: .spaceWhileComposing)
            typing.commit("Inn", reading: "inn", then: " ", via: .spaceWhileComposing)
            typing.startNewLine()
        }
        typing.commit("Smart", reading: "smart", then: " ", via: .spaceAfterCommit)
        typing.commit("Inn", reading: "inn", then: " ", via: .spaceAfterCommit)
        typing.startNewLine()

        #expect(typing.compounds(for: "sma").map(\.text) == ["Smart Inn"])
        #expect(typing.commit("Smart", reading: "smart", then: " ", via: .spaceWhileComposing)
            == ["Inn"])
    }

    @Test
    func differentPathsCountAsTheSamePhrase() {
        let typing = Typing()

        typing.commit("Smart", reading: "smart", then: " ", via: .spaceWhileComposing)
        typing.commit("Inn", reading: "inn")
        typing.startNewLine()
        #expect(typing.compounds(for: "sma").isEmpty)
        typing.commit("Smart", reading: "smart", then: " ", via: .spaceAfterCommit)
        typing.commit("Inn", reading: "inn")
        typing.startNewLine()

        #expect(typing.compounds(for: "sma").map(\.text) == ["Smart Inn"])
    }

    @Test(arguments: [
        ("", "SmartInn"),
        ("  ", "Smart  Inn"),
        ("　", "Smart　Inn")
    ])
    func keepsTheSeparatorAsTyped(separator: String, expected: String) {
        let typing = Typing()

        for _ in 0..<NextInputPredictionModel.minimumDirectSequenceCount {
            typing.commit("Smart", reading: "smart")
            for space in separator.map(String.init) {
                typing.typeSpaceAfterCommit(space)
            }
            typing.commit("Inn", reading: "inn")
            typing.startNewLine()
        }

        #expect(typing.compounds(for: "sma").map(\.text) == [expected])
    }

    @Test
    func spaceAndNoSpaceAreLearnedApart() {
        let typing = Typing()

        for _ in 0..<NextInputPredictionModel.minimumDirectSequenceCount {
            typing.commit("Smart", reading: "smart", then: " ", via: .spaceAfterCommit)
            typing.commit("Inn", reading: "inn")
            typing.startNewLine()
        }
        typing.commit("Smart", reading: "smart")
        typing.commit("Inn", reading: "inn")
        typing.startNewLine()

        #expect(typing.compounds(for: "sma").map(\.text) == ["Smart Inn"])
    }

    @Test
    func spaceWithoutAPreviousCommitIsNotLearned() {
        let typing = Typing()

        typing.typeSpaceAfterCommit(" ")
        typing.commit("Inn", reading: "inn")

        #expect(typing.compounds(for: "inn").isEmpty)
    }

    @Test
    func acceptedPhraseIsRegisteredWithItsSpace() throws {
        let typing = Typing()
        for _ in 0..<NextInputPredictionModel.minimumDirectSequenceCount {
            typing.commit("Smart", reading: "smart", then: " ", via: .spaceAfterCommit)
            typing.commit("Inn", reading: "inn")
            typing.startNewLine()
        }
        let phrase = try #require(typing.compounds(for: "sma").first)
        let entry = try #require(LearnedCompoundRegistration.entry(
            text: phrase.text,
            sourceTokens: phrase.sourceTokens,
            sourceReadings: phrase.sourceReadings
        ))
        var saved = ""
        let dictionary = UserDictionaryStore(entries: []) {
            saved = DictionarySerializer.text(from: $0)
        }

        try dictionary.add(reading: entry.reading, candidate: entry.candidate)
        try dictionary.add(reading: entry.reading, candidate: entry.candidate)

        #expect(entry == UserDictionaryRegistration(
            reading: "smartinn",
            candidate: "Smart Inn"
        ))
        let reloaded = try DictionaryParser().parse(saved)
        #expect(reloaded.map(\.reading) == ["smartinn"])
        #expect(reloaded.first?.candidates == ["Smart Inn"])
    }

    @Test
    func learnedSpaceSurvivesARestart() throws {
        let typing = Typing()
        for _ in 0..<NextInputPredictionModel.minimumDirectSequenceCount {
            typing.commit("Smart", reading: "smart", then: " ", via: .spaceOnSecondaryPanel)
            typing.commit("Inn", reading: "inn")
            typing.startNewLine()
        }

        let restarted = try typing.restarted()

        #expect(restarted.compounds(for: "sma").map(\.text) == ["Smart Inn"])
        #expect(restarted.compounds(for: "sma").first?.reading == "smartinn")
    }

    @Test
    func nextInputAfterTheSpacedWordOffersTheFollowingWord() {
        let typing = Typing()
        for _ in 0..<NextInputPredictionModel.minimumDirectSequenceCount {
            typing.commit("Smart", reading: "smart", then: " ", via: .spaceWhileComposing)
            typing.commit("Inn", reading: "inn")
            typing.startNewLine()
        }

        let following = typing.commit(
            "Smart",
            reading: "smart",
            then: " ",
            via: .spaceWhileComposing
        )

        #expect(following.contains("Inn"))
    }

    private final class Typing {
        private let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("next-input.json")
        private let writer: DeferredJSONFileWriter<NextInputPredictionModel>
        private let coordinator: NextInputCandidateCoordinator

        init(model: NextInputPredictionModel = NextInputPredictionModel()) {
            writer = DeferredJSONFileWriter(
                fileURL: fileURL,
                delay: 60,
                queueLabel: "myim.next-input-separator-test"
            )
            coordinator = NextInputCandidateCoordinator(
                predictionModel: model,
                writer: writer
            )
        }

        /// Commits `text` and the space after it, returning the next-input
        /// candidates shown afterwards
        @discardableResult
        func commit(
            _ text: String,
            reading: String,
            then space: String = "",
            via path: SpacePath = .spaceAfterCommit
        ) -> [String] {
            switch path {
            case .spaceWhileComposing:
                return learn([text + space], [reading], .directInput)
            case .spaceAfterCommit:
                let shown = learn([text], [reading], .directInput)
                if !space.isEmpty { typeSpaceAfterCommit(space) }
                return shown
            case .spaceOnSecondaryPanel:
                return learn(
                    NextInputLearningToken.texts([text], followedBy: space),
                    [reading],
                    .directInput
                )
            }
        }

        /// Selects `text` in the next-input panel, committing it with
        /// `space` when Space is the key that commits it
        func select(_ text: String, reading: String, then space: String = "") {
            learn(
                NextInputLearningToken.texts([text], followedBy: space),
                [reading],
                .acceptedCandidate
            )
        }

        /// Space with nothing composed, which the app inserts
        func typeSpaceAfterCommit(_ space: String) {
            coordinator.appendSeparatorToLastInput(space)
        }

        func startNewLine() {
            coordinator.breakSequence()
        }

        func compounds(for prefix: String) -> [LearnedCompoundPrediction] {
            coordinator.learnedCompoundPredictions(
                matchingPrefix: prefix,
                excluding: []
            )
        }

        func restarted() throws -> Typing {
            writer.flush()
            return Typing(model: try JSONDecoder().decode(
                NextInputPredictionModel.self,
                from: Data(contentsOf: fileURL)
            ))
        }

        @discardableResult
        private func learn(
            _ texts: [String],
            _ readings: [String],
            _ source: NextInputLearningSource
        ) -> [String] {
            coordinator.learnedCandidateModels(
                after: texts.last ?? "",
                committedTokens: zip(texts, readings).map {
                    NextInputLearningToken(text: $0.0, reading: $0.1)
                },
                learningSource: source,
                predictionEnabled: true,
                learningEnabled: true,
                breakPreviousSequence: false,
                limit: NextInputPredictionModel.maximumFollowersPerContext
            ).map(\.commitText)
        }
    }
}
