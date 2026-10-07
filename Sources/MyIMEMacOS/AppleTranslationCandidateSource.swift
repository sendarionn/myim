import MyIMECore

@MainActor
struct AppleTranslationCandidateSource {
    let targetIdentifiers: [String]

    func groups(for input: String) async throws
        -> [TranslationCandidateGroup] {
        try await TranslationCandidateSource(
            targetIdentifiers: targetIdentifiers
        ).groups(for: input) { input, targetIdentifier in
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
