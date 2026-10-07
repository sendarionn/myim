/// Translations of one source into one target language, shown as one panel
public struct TranslationCandidateGroup: Equatable, Sendable {
    public let targetIdentifier: String
    public let candidates: [Candidate]

    public init(targetIdentifier: String, candidates: [Candidate]) {
        self.targetIdentifier = targetIdentifier
        self.candidates = candidates
    }

    public func prefix(_ maximumCount: Int) -> Self {
        Self(
            targetIdentifier: targetIdentifier,
            candidates: Array(candidates.prefix(maximumCount))
        )
    }
}

public struct TranslationCandidateSource: Sendable {
    public let targetIdentifiers: [String]

    public init(targetIdentifiers: [String]) {
        self.targetIdentifiers = targetIdentifiers
    }

    /// Groups follow `targetIdentifiers`; languages without a usable
    /// translation are left out, and duplicates are removed per language
    @MainActor
    public func groups(
        for input: String,
        translate: (
            _ input: String,
            _ targetIdentifier: String
        ) async -> String?
    ) async throws -> [TranslationCandidateGroup] {
        var groups: [TranslationCandidateGroup] = []
        for targetIdentifier in targetIdentifiers {
            try Task.checkCancellation()
            guard let translated = await translate(input, targetIdentifier)
            else {
                continue
            }
            var seen = Set<String>()
            let candidates = TranslationCandidateNormalizer.wordCandidates(
                from: translated
            )
            .filter { $0 != input && seen.insert($0).inserted }
            .map {
                Candidate(
                    storageText: $0,
                    source: .translation,
                    reading: input,
                    attributes: [.generated]
                )
            }
            guard !candidates.isEmpty else { continue }
            groups.append(TranslationCandidateGroup(
                targetIdentifier: targetIdentifier,
                candidates: candidates
            ))
        }
        try Task.checkCancellation()
        return groups
    }
}

/// What one translation panel shows: its language name and the rows
public struct TranslationPanelContent: Equatable, Sendable {
    public let targetIdentifier: String
    public let caption: String?
    public let candidates: [String]

    /// One panel per group in the same order; the language name is shown
    /// only when several languages are configured
    public static func panels(
        for groups: [TranslationCandidateGroup],
        configuredLanguageCount: Int
    ) -> [Self] {
        groups.map {
            Self(
                targetIdentifier: $0.targetIdentifier,
                caption: configuredLanguageCount > 1
                    ? TranslationTargetLanguage.language(
                        forIdentifier: $0.targetIdentifier
                    )?.name ?? $0.targetIdentifier
                    : nil,
                candidates: $0.candidates.map(\.storageText)
            )
        }
    }
}
