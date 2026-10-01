import Testing
@testable import MyIMECore

@Suite
struct TranslationCandidateSessionTests {
    @Test
    func storesTranslationCandidatesWithTheirSourceMetadata() {
        var session = TranslationCandidateSession()

        let stored = session.store(
            translationCandidates(["candidate", "option"], reading: "候補"),
            for: "候補",
            channel: .normal
        )

        #expect(stored.map(\.storageText) == ["candidate", "option"])
        #expect(stored.allSatisfy { $0.hasSource(.translation) })
        #expect(stored.allSatisfy { $0.hasAttribute(.generated) })
        #expect(stored.allSatisfy { $0.origins.first?.reading == "候補" })
    }

    @Test
    func keepsNormalAndFuzzyResultsIndependent() {
        var session = TranslationCandidateSession()
        session.store(
            translationCandidates(["candidate"], reading: "候補"),
            for: "候補",
            channel: .normal
        )
        session.store(
            translationCandidates(["public offer"], reading: "公募"),
            for: "公募",
            channel: .fuzzy
        )

        #expect(session.contains("candidate", in: .normal))
        #expect(!session.contains("candidate", in: .fuzzy))
        #expect(session.candidates(for: "公募", channel: .fuzzy)
            .map(\.storageText) == ["public offer"])
    }

    @Test
    func replacesARepeatedSourceWithoutChangingItsOrder() {
        var session = TranslationCandidateSession()
        session.store(
            translationCandidates(["candidate"], reading: "候補"),
            for: "候補",
            channel: .normal
        )
        session.store(
            translationCandidates(["option"], reading: "候補"),
            for: "候補",
            channel: .normal
        )

        #expect(session.sources(in: .normal) == ["候補"])
        #expect(session.candidates(for: "候補", channel: .normal)
            .map(\.storageText) == ["option"])
        #expect(session.contains("candidate", in: .normal))
    }

    @Test
    func tracksVisibleSelectionAndResetsTheWholeSession() {
        var session = TranslationCandidateSession()
        let candidates = session.store(
            translationCandidates(["candidate", "option"], reading: "候補"),
            for: "候補",
            channel: .fuzzy
        )
        session.show(candidates)

        let selected = session.select(index: 1, returningToFuzzy: true)

        #expect(selected?.storageText == "option")
        #expect(session.selectedIndex == 1)
        #expect(session.returnWasFuzzy)

        session.reset()

        #expect(session.visibleCandidates.isEmpty)
        #expect(session.selectedIndex == nil)
        #expect(!session.returnWasFuzzy)
        #expect(session.sources(in: .fuzzy).isEmpty)
    }

    private func translationCandidates(
        _ values: [String],
        reading: String
    ) -> [Candidate] {
        values.map {
            Candidate(
                storageText: $0,
                source: .translation,
                reading: reading,
                attributes: [.generated]
            )
        }
    }
}
