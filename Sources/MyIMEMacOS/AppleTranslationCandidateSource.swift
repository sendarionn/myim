import MyIMECore

@MainActor
struct AppleTranslationCandidateSource {
    let targetIdentifiers: [String]

    func candidates(for input: String) async throws -> [Candidate] {
        try await TranslationCandidateSource(
            targetIdentifiers: targetIdentifiers
        ).candidates(for: input) { input, targetIdentifier in
#if canImport(Translation)
            if #available(macOS 15.0, *) {
                return await AppleTranslationCandidateProvider()
                    .translateJapanese(
                        input,
                        targetIdentifier: targetIdentifier
                    )
            }
#endif
            return nil
        }
    }
}
