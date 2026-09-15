import Testing
@testable import MyIMECore

@Suite
struct LinearCandidateNavigatorTests {
    @Test
    func dividesCandidatesIntoFourItemPages() {
        #expect(
            LinearCandidateNavigator.pageRange(
                containing: nil,
                pageSize: 4,
                candidateCount: 10
            ) == 0..<4
        )
        #expect(
            LinearCandidateNavigator.pageRange(
                containing: 4,
                pageSize: 4,
                candidateCount: 10
            ) == 4..<8
        )
        #expect(
            LinearCandidateNavigator.pageRange(
                containing: 9,
                pageSize: 4,
                candidateCount: 10
            ) == 8..<10
        )
    }

    @Test
    func movesOneCandidateAtATime() {
        #expect(LinearCandidateNavigator.index(
            from: 1,
            offset: 1,
            candidateCount: 8
        ) == 2)
        #expect(LinearCandidateNavigator.index(
            from: 5,
            offset: -1,
            candidateCount: 8
        ) == 4)
    }

    @Test
    func wrapsAtBothEnds() {
        #expect(LinearCandidateNavigator.index(
            from: 7,
            offset: 1,
            candidateCount: 8
        ) == 0)
        #expect(LinearCandidateNavigator.index(
            from: 0,
            offset: -1,
            candidateCount: 8
        ) == 7)
    }

    @Test
    func startsSelectionFromTheExpectedEnd() {
        #expect(LinearCandidateNavigator.index(
            from: nil,
            offset: 1,
            candidateCount: 8
        ) == 0)
        #expect(LinearCandidateNavigator.index(
            from: nil,
            offset: -1,
            candidateCount: 8
        ) == 7)
    }
}
