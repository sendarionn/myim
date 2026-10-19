import Testing
@testable import MyIMECore

@Suite
struct CandidateSearchSessionTests {
    @Test
    func replacingSearchInvalidatesOldToken() {
        let session = CandidateSearchSession()
        let old = session.begin(.fuzzy, query: "old")
        let current = session.begin(.fuzzy, query: "current")

        #expect(!session.isCurrent(old))
        #expect(session.isCurrent(current))
        #expect(session.query(for: .fuzzy) == "current")
    }

    @Test
    func kindsAreManagedIndependently() {
        let session = CandidateSearchSession()
        let fuzzy = session.begin(.fuzzy, query: "fuzzy")
        let postalAddress = session.begin(.postalAddress, query: "postal")

        session.cancel(.fuzzy)

        #expect(!session.isCurrent(fuzzy))
        #expect(session.isCurrent(postalAddress))
        #expect(session.query(for: .postalAddress) == "postal")
    }

    @Test
    func cancellingFuzzySearchPreventsDelayedResultFromBecomingCurrent() {
        let session = CandidateSearchSession()
        let fuzzy = session.begin(.fuzzy, query: "remaining-panel")

        session.cancel(.fuzzy)

        #expect(!session.isCurrent(fuzzy))
        #expect(session.query(for: .fuzzy) == nil)
    }

    @Test
    func cancelAllInvalidatesEveryToken() {
        let session = CandidateSearchSession()
        let postalAddress = session.begin(.postalAddress, query: "postal")
        let fuzzy = session.begin(.fuzzy, query: "fuzzy")

        session.cancelAll()

        #expect(!session.isCurrent(postalAddress))
        #expect(!session.isCurrent(fuzzy))
    }

    @Test
    func completingCurrentSearchRemovesOnlyItsToken() {
        let session = CandidateSearchSession()
        let translation = session.begin(.translation, query: "候補")
        let postalAddress = session.begin(.postalAddress, query: "1000001")

        session.complete(translation)

        #expect(!session.isCurrent(translation))
        #expect(session.query(for: .translation) == nil)
        #expect(session.isCurrent(postalAddress))
    }

    @Test
    func completingStaleSearchDoesNotRemoveItsReplacement() {
        let session = CandidateSearchSession()
        let stale = session.begin(.translation, query: "候補")
        let current = session.begin(.translation, query: "公募")

        session.complete(stale)

        #expect(session.isCurrent(current))
        #expect(session.query(for: .translation) == "公募")
    }

    @Test
    func finishingTaskKeepsItsQueryCurrent() {
        let session = CandidateSearchSession()
        let token = session.begin(.postalAddress, query: "1000001")

        session.finishTask(token)

        #expect(session.isCurrent(token))
        #expect(session.query(for: .postalAddress) == "1000001")
    }
}
