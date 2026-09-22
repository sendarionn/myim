public struct LayeredConversionEngine: Sendable {
    private let engines: [ConversionEngine]

    public init(engines: [ConversionEngine]) {
        self.engines = engines
    }

    public func candidates(for reading: String) -> [String] {
        candidateGroups(matching: reading).exact
    }

    public func readings(for candidate: String) -> [String] {
        unique(engines.flatMap { $0.readings(for: candidate) })
    }

    public func candidateGroups(
        matching reading: String,
        limit: Int = .max
    ) -> DictionaryCandidateGroups {
        guard limit > 0 else { return DictionaryCandidateGroups() }
        var seen = Set<String>()
        var exact: [String] = []
        var prefix: [String] = []
        for engine in engines {
            let groups = engine.candidateGroups(matching: reading)
            for candidate in groups.exact where seen.insert(candidate).inserted {
                exact.append(candidate)
                if exact.count == limit {
                    return DictionaryCandidateGroups(exact: exact)
                }
            }
        }
        for engine in engines {
            let groups = engine.candidateGroups(matching: reading)
            for candidate in groups.prefix where seen.insert(candidate).inserted {
                prefix.append(candidate)
                if exact.count + prefix.count == limit {
                    return DictionaryCandidateGroups(exact: exact, prefix: prefix)
                }
            }
        }
        return DictionaryCandidateGroups(exact: exact, prefix: prefix)
    }

    private func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}

public struct LayeredDictionaryContinuationCandidateGenerator: Sendable {
    private let generators: [DictionaryContinuationCandidateGenerator]

    public init(generators: [DictionaryContinuationCandidateGenerator]) {
        self.generators = generators
    }

    public func candidates(
        after committedValue: String,
        limit: Int = 8
    ) -> [String] {
        guard limit > 0 else { return [] }
        var seen = Set<String>()
        var result: [String] = []
        for generator in generators {
            for candidate in generator.candidates(
                after: committedValue,
                limit: limit
            ) where seen.insert(candidate).inserted {
                result.append(candidate)
                if result.count == limit { return result }
            }
        }
        return result
    }
}
