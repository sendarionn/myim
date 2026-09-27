import Foundation
import Testing
@testable import MyIMECore

@Suite
struct CandidateCommitNormalizerTests {
    @Test
    func removesPlaceholderWaveDashes() {
        #expect(CandidateCommitNormalizer.value(from: "〜個") == "個")
        #expect(CandidateCommitNormalizer.value(from: "約～個") == "約個")
    }

    @Test
    func keepsStandaloneWaveDash() {
        #expect(CandidateCommitNormalizer.value(from: "〜") == "〜")
    }

    @Test
    func replacesTheExistingMarkedRangeForAnActiveComposition() {
        let markedRange = NSRange(location: 12, length: 1)

        #expect(CandidateCommitReplacementRange.resolve(
            markedRange: markedRange,
            hasActiveComposition: true
        ) == markedRange)
        #expect(CandidateCommitReplacementRange.resolve(
            markedRange: markedRange,
            hasActiveComposition: false
        ).location == NSNotFound)
    }

    @Test
    func doesNotUseAnInvalidOrEmptyMarkedRange() {
        #expect(CandidateCommitReplacementRange.resolve(
            markedRange: NSRange(location: NSNotFound, length: 0),
            hasActiveComposition: true
        ).location == NSNotFound)
        #expect(CandidateCommitReplacementRange.resolve(
            markedRange: NSRange(location: 12, length: 0),
            hasActiveComposition: true
        ).location == NSNotFound)
    }
}
