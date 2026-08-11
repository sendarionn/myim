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
    func cancelAllInvalidatesEveryToken() {
        let session = SuggestionSearchSession()
        let official = session.begin(.official, query: "official")
        let fuzzy = session.begin(.fuzzy, query: "fuzzy")

        session.cancelAll()

        #expect(!session.isCurrent(official))
        #expect(!session.isCurrent(fuzzy))
    }
}
