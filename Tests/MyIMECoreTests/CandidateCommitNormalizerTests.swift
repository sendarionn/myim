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
    func replacesTheExistingMarkedRangeWhenCommittingASelectedCandidate() {
        let markedRange = NSRange(location: 12, length: 1)

        #expect(CandidateCommitReplacementRange.resolve(
            markedRange: markedRange,
            replacingMarkedText: true
        ) == markedRange)
        #expect(CandidateCommitReplacementRange.resolve(
            markedRange: markedRange,
            replacingMarkedText: false
        ).location == NSNotFound)
    }
}
