public struct CandidateSourceContext: Equatable, Sendable {
    public let input: String
    public let conversionReading: String
    public let japaneseReading: String

    public init(
        input: String,
        conversionReading: String,
        japaneseReading: String
    ) {
        self.input = input
        self.conversionReading = conversionReading
        self.japaneseReading = japaneseReading
    }
}

public protocol CandidateSource: Sendable {
    var kind: CandidateSourceKind { get }
    func candidates(for context: CandidateSourceContext) async -> [Candidate]
}

public enum CandidateSourceCollector {
    public static func candidates(
        from sources: [any CandidateSource],
        context: CandidateSourceContext
    ) async -> [Candidate] {
        await withTaskGroup(
            of: (Int, [Candidate]).self,
            returning: [(Int, [Candidate])].self
        ) { group in
            for (index, source) in sources.enumerated() {
                group.addTask {
                    (index, await source.candidates(for: context))
                }
            }
            var results: [(Int, [Candidate])] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
        .sorted { $0.0 < $1.0 }
        .flatMap(\.1)
        .mergingDuplicateCandidateOrigins()
    }
}

public struct WikipediaCandidateSource: CandidateSource {
    public let kind = CandidateSourceKind.wikipedia

    public init() {}

    public func candidates(
        for context: CandidateSourceContext
    ) async -> [Candidate] {
        let values = (try? await WikipediaSuggestionClient().suggestions(
            for: context.japaneseReading
        )) ?? []
        return values.map {
            Candidate(
                storageText: $0,
                source: kind,
                reading: context.conversionReading,
                isLearnable: true
            )
        }
    }
}

public struct GoogleJapaneseInputCandidateSource: CandidateSource {
    public let kind = CandidateSourceKind.googleJapaneseInput

    public init() {}

    public func candidates(
        for context: CandidateSourceContext
    ) async -> [Candidate] {
        let values = (try? await GoogleJapaneseInputClient().candidates(
            for: context.japaneseReading
        )) ?? []
        return values.map {
            Candidate(
                storageText: $0,
                source: kind,
                reading: context.conversionReading,
                isLearnable: true
            )
        }
    }
}

private extension Array where Element == Candidate {
    func mergingDuplicateCandidateOrigins() -> [Candidate] {
        var result: [Candidate] = []
        var indexByText: [String: Int] = [:]
        for candidate in self {
            if let index = indexByText[candidate.storageText] {
                result[index] = result[index].mergingOrigins(from: candidate)
            } else {
                indexByText[candidate.storageText] = result.count
                result.append(candidate)
            }
        }
        return result
    }
}
