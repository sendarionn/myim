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
    func doesNotGenerateLeadingParticleCandidate() {
        #expect(candidates(for: "hakouho").isEmpty)
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
    func identifiesCandidatesThatExistOnlyAsParticleCompositions() {
        #expect(
            JapaneseParticleCandidateGenerator.generatedOnlyCandidates(
                generated: ["候補を", "候補につき"],
                exactDictionaryCandidates: ["候補を"]
            ) == ["候補につき"]
        )
    }

    @Test
    func selectedCompositionCanBecomeAnExactUserDictionaryCandidate() throws {
        let candidate = try #require(candidates(for: "kouhowo").first)
        let entries = UserDictionaryEditor.adding(
            reading: "kouhowo",
            candidate: candidate,
            to: []
        )

        #expect(
            ConversionEngine(entries: entries).candidates(for: "kouhowo")
                == ["候補を"]
        )
        #expect(
            JapaneseParticleCandidateGenerator.generatedOnlyCandidates(
                generated: [candidate],
                exactDictionaryCandidates: [candidate]
            ).isEmpty
        )
    }

    private func candidates(for input: String) -> [String] {
        JapaneseParticleCandidateGenerator.candidates(for: input) {
            dictionary[$0] ?? []
        }
    }
}
