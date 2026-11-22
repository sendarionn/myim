import Testing
@testable import MyIMECore

@Suite
struct CandidateAccessoryTests {
    @Test(arguments: [
        (false, false, CandidateAccessory.none),
        (true, false, .alternateCommit),
        (false, true, .bookmark),
        (true, true, .bookmark)
    ])
    func bookmarkSymbolTakesThePlaceOfTheDot(
        hasDistinctCommitText: Bool,
        isBookmark: Bool,
        expected: CandidateAccessory
    ) {
        #expect(CandidateAccessory.resolve(
            hasDistinctCommitText: hasDistinctCommitText,
            isBookmark: isBookmark
        ) == expected)
    }
}
