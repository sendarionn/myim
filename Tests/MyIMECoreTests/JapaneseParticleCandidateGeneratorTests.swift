import Testing
@testable import MyIMECore

@Suite
struct JapaneseParticleCandidateGeneratorTests {
    private let dictionary = [
        "kouho": ["候補"],
        "sentaku": ["選択"]
    ]

    @Test
    func keepsTrailingParticleInHiragana() {
        #expect(candidates(for: "kouhowo") == ["候補を"])
    }

    @Test
    func keepsLeadingParticleInHiragana() {
        #expect(candidates(for: "hakouho") == ["は候補"])
    }

    @Test
    func supportsCompoundParticles() {
        #expect(candidates(for: "kouhonite") == ["候補にて"])
        #expect(candidates(for: "kouhonotame") == ["候補のため"])
        #expect(candidates(for: "kouhonitsuki") == ["候補につき"])
        #expect(candidates(for: "kouhoniyotte") == ["候補によって"])
        #expect(candidates(for: "kouhonikanshite") == ["候補に関して"])
    }

    @Test
    func doesNotSplitParticleInsideInput() {
        #expect(candidates(for: "kouhowosentaku").isEmpty)
    }

    @Test
    func requiresAnExactDictionaryStem() {
        #expect(candidates(for: "mityakuwp").isEmpty)
    }

    @Test
    func excludesOnlyGeneratedCandidatesFromLearning() {
        #expect(
            JapaneseParticleCandidateGenerator.nonLearnableCandidates(
                generated: ["候補を", "候補につき"],
                exactDictionaryCandidates: ["候補を"]
            ) == ["候補につき"]
        )
    }

    private func candidates(for input: String) -> [String] {
        JapaneseParticleCandidateGenerator.candidates(for: input) {
            dictionary[$0] ?? []
        }
    }
}
