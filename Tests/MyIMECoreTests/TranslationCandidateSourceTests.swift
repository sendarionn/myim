import Testing
@testable import MyIMECore

@Suite
struct TranslationCandidateSourceTests {
    @Test @MainActor
    func preservesTargetOrderAndRemovesDuplicateTranslations() async throws {
        let source = TranslationCandidateSource(
            targetIdentifiers: ["en", "fr"]
        )

        let candidates = try await source.candidates(for: "候補") {
            _, target in
            target == "en" ? "candidate / option" : "option / candidat"
        }

        #expect(candidates.map(\.storageText) == [
            "candidate", "option", "candidat"
        ])
    }

    @Test @MainActor
    func createsStructuredTranslationCandidates() async throws {
        let source = TranslationCandidateSource(targetIdentifiers: ["en"])

        let candidates = try await source.candidates(for: "候補") { _, _ in
            "Candidate"
        }

        #expect(candidates.count == 1)
        #expect(candidates[0].storageText == "candidate")
        #expect(candidates[0].hasSource(.translation))
        #expect(candidates[0].hasAttribute(.generated))
        #expect(candidates[0].origins.first?.reading == "候補")
    }

    @Test @MainActor
    func skipsUnavailableTargetsAndTheUnchangedInput() async throws {
        let source = TranslationCandidateSource(
            targetIdentifiers: ["en", "fr"]
        )

        let candidates = try await source.candidates(for: "候補") {
            input, target in
            target == "en" ? nil : input
        }

        #expect(candidates.isEmpty)
    }
}
