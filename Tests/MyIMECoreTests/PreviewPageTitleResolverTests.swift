import Testing
@testable import MyIMECore

@Suite
struct PreviewPageTitleResolverTests {
    @Test
    func usesRomanInputBeforeCandidateSelection() {
        #expect(
            PreviewPageTitleResolver.pageTitle(
                input: "kouzou",
                selectedCandidate: nil
            ) == "kouzou"
        )
    }

    @Test
    func usesCandidateAfterSelection() {
        #expect(
            PreviewPageTitleResolver.pageTitle(
                input: "kouzou",
                selectedCandidate: "構造"
            ) == "構造"
        )
    }
}
