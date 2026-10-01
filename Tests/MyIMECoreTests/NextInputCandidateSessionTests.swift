import Testing
@testable import MyIMECore

@Suite struct NextInputCandidateSessionTests {
    @Test func beginsAndResetsOneCoherentSession() {
        var session = NextInputCandidateSession()

        session.begin(context: "よろしく", candidates: ["お願いします", "お願いいたします"])
        #expect(session.context == "よろしく")
        #expect(session.candidates == ["お願いします", "お願いいたします"])
        #expect(session.selectedIndex == nil)

        session.clearCandidates()
        #expect(session.candidates.isEmpty)
        #expect(session.context == "よろしく")

        session.reset()
        #expect(session == NextInputCandidateSession())
    }

    @Test func preservesSelectedCandidateWhenCandidatesAreUpdated() {
        var session = NextInputCandidateSession()
        session.begin(context: "a", candidates: ["b", "c"])
        #expect(session.select(index: 1) == "c")

        session.updateCandidates(["x", "c", "d"])
        #expect(session.selectedIndex == 1)
        #expect(session.selectedCandidate == "c")
    }

    @Test func clearsSelectionWhenSelectedCandidateDisappears() {
        var session = NextInputCandidateSession()
        session.begin(context: "a", candidates: ["b", "c"])
        _ = session.select(index: 1)

        session.updateCandidates(["b", "d"])
        #expect(session.selectedIndex == nil)
    }

    @Test func calculatesLinearAndWrappedNavigation() {
        var session = NextInputCandidateSession()
        session.begin(context: "a", candidates: ["b", "c", "d"])

        #expect(session.linearSelectionIndex(offset: 1) == 0)
        #expect(session.wrappedSelectionIndex(offset: -1) == 2)
        _ = session.select(index: 2)
        #expect(session.wrappedSelectionIndex(offset: 1) == 0)
    }

    @Test func removesOnlyTheSelectedCandidate() {
        var session = NextInputCandidateSession()
        session.begin(context: "a", candidates: ["b", "c", "d"])
        _ = session.select(index: 1)

        #expect(session.removeSelectedCandidate() == "c")
        #expect(session.candidates == ["b", "d"])
        #expect(session.selectedIndex == nil)
        #expect(session.context == "a")
    }
}
