import Testing
@testable import MyIMECore

@Suite
struct SuggestionSearchSessionTests {
    @Test
    func replacingSearchInvalidatesOldToken() {
        let session = SuggestionSearchSession()
        let old = session.begin(.fuzzy, query: "old")
        let current = session.begin(.fuzzy, query: "current")

        #expect(!session.isCurrent(old))
        #expect(session.isCurrent(current))
        #expect(session.query(for: .fuzzy) == "current")
    }

    @Test
    func kindsAreManagedIndependently() {
        let session = SuggestionSearchSession()
        let fuzzy = session.begin(.fuzzy, query: "fuzzy")
        let official = session.begin(.official, query: "official")

        session.cancel(.fuzzy)

        #expect(!session.isCurrent(fuzzy))
        #expect(session.isCurrent(official))
        #expect(session.query(for: .official) == "official")
    }

    @Test
    func cancellingFuzzySearchPreventsDelayedResultFromBecomingCurrent() {
        let session = SuggestionSearchSession()
        let fuzzy = session.begin(.fuzzy, query: "remaining-panel")

        session.cancel(.fuzzy)

        #expect(!session.isCurrent(fuzzy))
        #expect(session.query(for: .fuzzy) == nil)
    }

    @Test
    func cancelAllInvalidatesEveryToken() {
        let session = SuggestionSearchSession()
        let official = session.begin(.official, query: "official")
        let fuzzy = session.begin(.fuzzy, query: "fuzzy")

        session.cancelAll()

        #expect(!session.isCurrent(official))
        #expect(!session.isCurrent(fuzzy))
    }

    @Test
    func completingCurrentSearchRemovesOnlyItsToken() {
        let session = SuggestionSearchSession()
        let translation = session.begin(.translation, query: "候補")
        let official = session.begin(.official, query: "kouho")

        session.complete(translation)

        #expect(!session.isCurrent(translation))
        #expect(session.query(for: .translation) == nil)
        #expect(session.isCurrent(official))
    }

    @Test
    func completingStaleSearchDoesNotRemoveItsReplacement() {
        let session = SuggestionSearchSession()
        let stale = session.begin(.translation, query: "候補")
        let current = session.begin(.translation, query: "公募")

        session.complete(stale)

        #expect(session.isCurrent(current))
        #expect(session.query(for: .translation) == "公募")
    }

    @Test
    func finishingTaskKeepsItsQueryCurrent() {
        let session = SuggestionSearchSession()
        let token = session.begin(.official, query: "kouho")

        session.finishTask(token)

        #expect(session.isCurrent(token))
        #expect(session.query(for: .official) == "kouho")
    }
}
