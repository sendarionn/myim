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
        let external = session.begin(.external, query: "external")

        session.cancel(.fuzzy)

        #expect(!session.isCurrent(fuzzy))
        #expect(session.isCurrent(external))
        #expect(session.query(for: .external) == "external")
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
        let external = session.begin(.external, query: "external")
        let fuzzy = session.begin(.fuzzy, query: "fuzzy")

        session.cancelAll()

        #expect(!session.isCurrent(external))
        #expect(!session.isCurrent(fuzzy))
    }

    @Test
    func completingCurrentSearchRemovesOnlyItsToken() {
        let session = CandidateSearchSession()
        let translation = session.begin(.translation, query: "候補")
        let external = session.begin(.external, query: "kouho")

        session.complete(translation)

        #expect(!session.isCurrent(translation))
        #expect(session.query(for: .translation) == nil)
        #expect(session.isCurrent(external))
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
        let token = session.begin(.external, query: "kouho")

        session.finishTask(token)

        #expect(session.isCurrent(token))
        #expect(session.query(for: .external) == "kouho")
    }
}
