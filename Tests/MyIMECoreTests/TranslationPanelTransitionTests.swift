import Foundation
import Testing
@testable import MyIMECore

/// How the translation panels follow the candidate they translate while
/// moving between the primary panel, the secondary panel and translations
@Suite
@MainActor
struct TranslationPanelTransitionTests {
    @Test
    func movingWithinOnePanelKeepsTranslationsUntilReplaced() {
        let session = shownSession(channel: .standard)

        #expect(session.transition(toSourceIn: .standard, translates: true)
            == .keepUntilReplaced)
    }

    @Test
    func returningFromTheSecondaryPanelClosesItsTranslations() {
        let session = shownSession(channel: .fuzzy)

        #expect(session.transition(toSourceIn: .standard, translates: true)
            == .close)
    }

    @Test
    func enteringTheSecondaryPanelClosesTheStandardTranslations() {
        let session = shownSession(channel: .standard)

        #expect(session.transition(toSourceIn: .fuzzy, translates: true)
            == .close)
    }

    @Test
    func sourceWithoutTranslationLeavesNoTranslations() {
        let session = shownSession(channel: .standard)

        #expect(session.transition(toSourceIn: .standard, translates: false)
            == .close)
    }

    @Test
    func nothingShownHasNothingToClose() {
        let session = TranslationCandidateSession()

        #expect(session.transition(toSourceIn: .fuzzy, translates: true)
            == .keepUntilReplaced)
    }

    @Test
    func primaryToTranslationsAndBackRestoresThePrimarySource() {
        var session = shownSession(channel: .standard)

        session.select(
            TranslationCandidateSelection(groupIndex: 0, candidateIndex: 0),
            returningToFuzzy: false
        )
        let move = session.moveHorizontally(movingLeft: false)

        #expect(move == .returnedToSource)
        #expect(!session.returnWasFuzzy)
        #expect(session.selection == nil)
    }

    @Test
    func secondaryToTranslationsAndBackRestoresTheSecondarySource() {
        var fuzzy = FuzzyCandidateSession(candidates: ["候補", "公募"].map {
            FuzzyCandidate(storageText: $0, reading: "kouho", distance: 1)
        })
        fuzzy.select(index: 1)
        var session = shownSession(channel: .fuzzy)

        session.select(
            TranslationCandidateSelection(groupIndex: 0, candidateIndex: 0),
            returningToFuzzy: fuzzy.selectedIndex != nil
        )
        let move = session.moveHorizontally(movingLeft: true)

        #expect(move == .returnedToSource)
        #expect(session.returnWasFuzzy)
        #expect(fuzzy.selectedCandidate?.storageText == "公募")
    }

    @Test
    func lateTranslationOfTheSecondaryCandidateIsNotShown() async {
        let searches = CandidateSearchCoordinator()
        var selectedSource = "公募"
        var shown: [String] = []

        searches.start(
            .translation,
            query: "公募",
            operation: {
                try await Task.sleep(for: .milliseconds(50))
                return "public offering"
            },
            validate: { selectedSource == "公募" },
            apply: { shown.append($0) }
        )
        selectedSource = "候補"
        searches.start(
            .translation,
            query: "候補",
            operation: { "candidate" },
            validate: { selectedSource == "候補" },
            apply: { shown.append($0) }
        )
        try? await Task.sleep(for: .milliseconds(120))

        #expect(shown == ["candidate"])
    }

    @Test
    func lateTranslationAfterMovingToAnUntranslatedCandidateIsNotShown()
        async {
        let searches = CandidateSearchCoordinator()
        var selectedSource = "公募"
        var shown: [String] = []

        searches.start(
            .translation,
            query: "公募",
            operation: {
                try await Task.sleep(for: .milliseconds(50))
                return "public offering"
            },
            validate: { selectedSource == "公募" },
            apply: { shown.append($0) }
        )
        selectedSource = "kouho"
        searches.cancel(.translation)
        try? await Task.sleep(for: .milliseconds(120))

        #expect(shown.isEmpty)
    }

    private func shownSession(
        channel: TranslationCandidateChannel
    ) -> TranslationCandidateSession {
        var session = TranslationCandidateSession()
        session.show([TranslationCandidateGroup(
            targetIdentifier: "en",
            candidates: [Candidate(storageText: "candidate", source: .translation)]
        )], channel: channel)
        return session
    }
}
