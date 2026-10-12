import Testing
@testable import MyIMECore

/// Translations belong to the candidate and candidate group they were made
/// for; moving from fuzzy candidate A to standard candidate B switches them
@Suite
struct TranslationSourceSwitchTests {
    private let fuzzyA = TranslationSource(text: "公募", channel: .fuzzy)
    private let standardB = TranslationSource(text: "候補", channel: .standard)

    @Test
    func returningToTheStandardCandidateMakesItTheSource() {
        let session = showing(["public offering"], for: fuzzyA)

        #expect(session.isShowingTranslations(of: fuzzyA))
        #expect(!session.isShowingTranslations(of: standardB))
        #expect(session.transition(toSourceIn: .standard, translates: true)
            == .close)
    }

    @Test
    func translationsOfTheStandardCandidateReplaceTheFuzzyOnes() {
        var session = showing(["public offering"], for: fuzzyA)

        session.show(
            [group(["candidate"])],
            channel: .standard,
            source: standardB.text
        )

        #expect(session.isShowingTranslations(of: standardB))
        #expect(!session.isShowingTranslations(of: fuzzyA))
        #expect(session.visibleChannel == .standard)
    }

    @Test
    func leftoverFuzzyTranslationsAreNotADestinationFromTheStandardCandidate() {
        let session = showing(["public offering"], for: fuzzyA)

        // InputController enters translations only when this holds
        #expect(!session.isShowingTranslations(of: standardB))
    }

    @Test
    func sameTextInAnotherGroupIsAnotherSource() {
        let session = showing(["candidate"], for: TranslationSource(
            text: "候補",
            channel: .fuzzy
        ))

        #expect(!session.isShowingTranslations(of: standardB))
    }

    @Test
    func untranslatedStandardCandidateLeavesNoFuzzyTranslations() {
        let session = showing(["public offering"], for: fuzzyA)

        #expect(session.transition(toSourceIn: .standard, translates: false)
            == .close)
    }

    @Test
    func lateResultForTheFuzzyCandidateDoesNotMatchTheCurrentSource() {
        let currentSource = standardB
        let lateResult = TranslationSource(text: "公募", channel: .fuzzy)

        // InputController applies a result only for the current source
        #expect(lateResult != currentSource)
        #expect(TranslationSource(text: "候補", channel: .standard)
            == currentSource)
    }

    @Test
    func hidingClearsTheSourceTogetherWithThePanels() {
        var session = showing(["public offering"], for: fuzzyA)

        session.show([], channel: .standard)

        #expect(session.visibleSource == nil)
        #expect(!session.hasVisibleCandidates)
        #expect(session.transition(toSourceIn: .standard, translates: true)
            == .keepUntilReplaced)
    }

    @Test
    func resetForgetsTheShownSource() {
        var session = showing(["public offering"], for: fuzzyA)

        session.reset()

        #expect(session.visibleSource == nil)
        #expect(!session.isShowingTranslations(of: fuzzyA))
    }

    private func showing(
        _ values: [String],
        for source: TranslationSource
    ) -> TranslationCandidateSession {
        var session = TranslationCandidateSession()
        session.show(
            [group(values)],
            channel: source.channel,
            source: source.text
        )
        return session
    }

    private func group(_ values: [String]) -> TranslationCandidateGroup {
        TranslationCandidateGroup(
            targetIdentifier: "en",
            candidates: values.map {
                Candidate(storageText: $0, source: .translation)
            }
        )
    }
}
