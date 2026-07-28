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
}
