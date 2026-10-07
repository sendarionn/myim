import Testing
@testable import MyIMECore

@Suite
struct TranslationCandidateSessionTests {
    @Test
    func storesEveryLanguageGroupForOneSource() {
        var session = TranslationCandidateSession()

        session.store(
            [group("en", ["love"]), group("zh-Hans", ["爱"])],
            for: "愛",
            channel: .normal
        )

        #expect(session.groups(for: "愛", channel: .normal)
            .map(\.targetIdentifier) == ["en", "zh-Hans"])
        #expect(session.contains("love", in: .normal))
        #expect(session.contains("爱", in: .normal))
    }

    @Test
    func keepsNormalAndFuzzyResultsIndependent() {
        var session = TranslationCandidateSession()
        session.store([group("en", ["candidate"])], for: "候補", channel: .normal)
        session.store(
            [group("en", ["public offer"])],
            for: "公募",
            channel: .fuzzy
        )

        #expect(session.contains("candidate", in: .normal))
        #expect(!session.contains("candidate", in: .fuzzy))
        #expect(session.groups(for: "公募", channel: .fuzzy)
            .flatMap(\.candidates).map(\.storageText) == ["public offer"])
    }

    @Test
    func replacesARepeatedSourceWithoutChangingItsOrder() {
        var session = TranslationCandidateSession()
        session.store([group("en", ["candidate"])], for: "候補", channel: .normal)
        session.store([group("en", ["option"])], for: "候補", channel: .normal)

        #expect(session.sources(in: .normal) == ["候補"])
        #expect(session.groups(for: "候補", channel: .normal)
            .flatMap(\.candidates).map(\.storageText) == ["option"])
    }

    @Test
    func tracksTheSelectedLanguageAndRow() {
        var session = shownSession(channel: .normal)

        let selected = session.select(
            TranslationCandidateSelection(groupIndex: 1, candidateIndex: 1),
            returningToFuzzy: false
        )

        #expect(selected?.storageText == "爱情")
        #expect(session.selectedTargetIdentifier == "zh-Hans")
        #expect(session.selection?.candidateIndex == 1)
    }

    @Test
    func leftMovesAwayFromNormalCandidatesAndRightComesBack() {
        var session = shownSession(channel: .normal)
        enter(&session)

        #expect(session.moveHorizontally(movingLeft: true)
            == .selected(candidate("爱")))
        #expect(session.moveHorizontally(movingLeft: true)
            == .selected(candidate("사랑")))
        #expect(session.moveHorizontally(movingLeft: true) == .unchanged)
        #expect(session.moveHorizontally(movingLeft: false)
            == .selected(candidate("爱")))
        #expect(session.moveHorizontally(movingLeft: false)
            == .selected(candidate("love")))
        #expect(session.moveHorizontally(movingLeft: false) == .returnedToSource)
        #expect(session.selection == nil)
    }

    @Test
    func rightMovesAwayFromFuzzySuggestions() {
        var session = shownSession(channel: .fuzzy)
        enter(&session)

        #expect(session.moveHorizontally(movingLeft: false)
            == .selected(candidate("爱")))
        #expect(session.moveHorizontally(movingLeft: false)
            == .selected(candidate("사랑")))
        #expect(session.moveHorizontally(movingLeft: true)
            == .selected(candidate("爱")))
        #expect(session.moveHorizontally(movingLeft: true)
            == .selected(candidate("love")))
        #expect(session.moveHorizontally(movingLeft: true) == .returnedToSource)
    }

    @Test
    func verticalMovesStayInsideTheLanguageAndWrap() {
        var session = shownSession(channel: .normal)
        enter(&session)

        #expect(session.moveVertically(by: 1)?.storageText == "affection")
        #expect(session.moveVertically(by: 1)?.storageText == "adoration")
        #expect(session.moveVertically(by: 1)?.storageText == "devotion")
        #expect(session.moveVertically(by: 1)?.storageText == "love")
        #expect(session.moveVertically(by: -1)?.storageText == "devotion")
        #expect(session.selectedTargetIdentifier == "en")
    }

    @Test
    func horizontalMovesKeepTheRowOrClampIt() {
        var session = shownSession(channel: .normal)
        session.select(
            TranslationCandidateSelection(groupIndex: 0, candidateIndex: 3),
            returningToFuzzy: false
        )

        #expect(session.moveHorizontally(movingLeft: true)
            == .selected(candidate("爱情")))
        #expect(session.selection
            == TranslationCandidateSelection(groupIndex: 1, candidateIndex: 1))
        #expect(session.moveHorizontally(movingLeft: true)
            == .selected(candidate("사랑")))
        #expect(session.moveHorizontally(movingLeft: false)
            == .selected(candidate("爱")))
    }

    @Test
    func showingNewPanelsDropsTheSelection() {
        var session = shownSession(channel: .normal)
        enter(&session)

        session.show([group("en", ["passion"])], channel: .normal)

        #expect(session.selection == nil)
        #expect(session.visibleGroups.count == 1)
    }

    @Test
    func resetClearsEveryLanguagePanel() {
        var session = shownSession(channel: .fuzzy)
        session.select(
            TranslationCandidateSelection(groupIndex: 0, candidateIndex: 0),
            returningToFuzzy: true
        )
        #expect(session.returnWasFuzzy)

        session.reset()

        #expect(session.visibleGroups.isEmpty)
        #expect(session.visibleChannel == nil)
        #expect(session.selection == nil)
        #expect(!session.returnWasFuzzy)
        #expect(session.sources(in: .fuzzy).isEmpty)
    }

    @Test
    func singleLanguagePanelKeepsItsSelectionFlow() {
        var session = TranslationCandidateSession()
        session.show([group("en", ["candidate", "option"])], channel: .normal)
        enter(&session)

        #expect(session.moveVertically(by: 1)?.storageText == "option")
        #expect(session.moveHorizontally(movingLeft: true) == .unchanged)
        #expect(session.moveHorizontally(movingLeft: false) == .returnedToSource)
    }

    /// English has four rows, Chinese two and Korean one
    private func shownSession(
        channel: TranslationCandidateChannel
    ) -> TranslationCandidateSession {
        var session = TranslationCandidateSession()
        let groups = [
            group("en", ["love", "affection", "adoration", "devotion"]),
            group("zh-Hans", ["爱", "爱情"]),
            group("ko", ["사랑"])
        ]
        session.store(groups, for: "愛", channel: channel)
        session.show(groups, channel: channel)
        return session
    }

    private func enter(_ session: inout TranslationCandidateSession) {
        session.select(
            TranslationCandidateSelection(groupIndex: 0, candidateIndex: 0),
            returningToFuzzy: false
        )
    }

    private func group(
        _ identifier: String,
        _ values: [String]
    ) -> TranslationCandidateGroup {
        TranslationCandidateGroup(
            targetIdentifier: identifier,
            candidates: values.map(candidate)
        )
    }

    private func candidate(_ value: String) -> Candidate {
        Candidate(
            storageText: value,
            source: .translation,
            reading: "愛",
            attributes: [.generated]
        )
    }
}
