public struct TranslationCandidateSource: Sendable {
    public let targetIdentifiers: [String]

    public init(targetIdentifiers: [String]) {
        self.targetIdentifiers = targetIdentifiers
    }

    @MainActor
    public func candidates(
        for input: String,
        translate: (
            _ input: String,
            _ targetIdentifier: String
        ) async -> String?
    ) async throws -> [Candidate] {
        var values: [String] = []
        for targetIdentifier in targetIdentifiers {
            try Task.checkCancellation()
            guard let translated = await translate(input, targetIdentifier)
            else {
                continue
            }
            values.append(contentsOf:
                TranslationCandidateNormalizer.wordCandidates(
                    from: translated
                ).filter { $0 != input }
            )
        }
        try Task.checkCancellation()

        var seen = Set<String>()
        return values
            .filter { seen.insert($0).inserted }
            .map {
                Candidate(
                    storageText: $0,
                    source: .translation,
                    reading: input,
                    attributes: [.generated]
                )
            }
    }
}
