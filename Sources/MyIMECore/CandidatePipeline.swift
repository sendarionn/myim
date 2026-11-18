public struct CandidatePipeline: Sendable {
    public struct StructuredInput: Sendable {
        public let kana: [Candidate]
        public let direct: [Candidate]
        public let secondary: [Candidate]
        public let other: [Candidate]
        public let english: [Candidate]
        public let trailing: [Candidate]
        public let recencyRanks: [String: Int]
        /// Ranks used within `secondary` instead of `recencyRanks`
        public let secondaryRanks: [String: Int]?
        public let inflectionBaseRanks: [String: Int]
        public let contextualCandidates: [String]
        public let prioritizeKana: Bool
        public let includeAutomaticKanaCandidates: Bool

        public init(
            kana: [Candidate],
            direct: [Candidate],
            secondary: [Candidate] = [],
            other: [Candidate],
            english: [Candidate] = [],
            trailing: [Candidate] = [],
            recencyRanks: [String: Int],
            secondaryRanks: [String: Int]? = nil,
            inflectionBaseRanks: [String: Int] = [:],
            contextualCandidates: [String] = [],
            prioritizeKana: Bool,
            includeAutomaticKanaCandidates: Bool = true
        ) {
            self.kana = kana
            self.direct = direct
            self.secondary = secondary
            self.other = other
            self.english = english
            self.trailing = trailing
            self.recencyRanks = recencyRanks
            self.secondaryRanks = secondaryRanks
            self.inflectionBaseRanks = inflectionBaseRanks
            self.contextualCandidates = contextualCandidates
            self.prioritizeKana = prioritizeKana
            self.includeAutomaticKanaCandidates = includeAutomaticKanaCandidates
        }
    }

    public struct Input: Sendable {
        public let kana: [String]
        public let direct: [String]
        public let secondary: [String]
        public let other: [String]
        public let english: [String]
        public let trailing: [String]
        public let recencyRanks: [String: Int]
        /// Ranks used within `secondary` instead of `recencyRanks`
        public let secondaryRanks: [String: Int]?
        public let contextualCandidates: [String]
        public let prioritizeKana: Bool
        public let includeAutomaticKanaCandidates: Bool

        public init(
            kana: [String],
            direct: [String],
            secondary: [String] = [],
            other: [String],
            english: [String] = [],
            trailing: [String] = [],
            recencyRanks: [String: Int],
            secondaryRanks: [String: Int]? = nil,
            contextualCandidates: [String] = [],
            prioritizeKana: Bool,
            includeAutomaticKanaCandidates: Bool = true
        ) {
            self.kana = kana
            self.direct = direct
            self.secondary = secondary
            self.other = other
            self.english = english
            self.trailing = trailing
            self.recencyRanks = recencyRanks
            self.secondaryRanks = secondaryRanks
            self.contextualCandidates = contextualCandidates
            self.prioritizeKana = prioritizeKana
            self.includeAutomaticKanaCandidates = includeAutomaticKanaCandidates
        }
    }

    public init() {}

    public func candidates(from input: StructuredInput) -> [Candidate] {
        let secondaryByText = Dictionary(
            grouping: input.secondary,
            by: \.storageText
        ).mapValues { matches in
            matches.dropFirst().reduce(matches[0]) {
                $0.mergingOrigins(from: $1)
            }
        }
        let secondaryOrder = Dictionary(
            input.secondary.enumerated().map {
                ($0.element.storageText, $0.offset)
            },
            uniquingKeysWith: min
        )
        let directRanks = input.secondaryRanks ?? [:]
        let directlyRanked = directRanks.keys.filter {
            secondaryByText[$0] != nil
        }.sorted {
            if directRanks[$0] != directRanks[$1] {
                return (directRanks[$0] ?? 0) > (directRanks[$1] ?? 0)
            }
            return (secondaryOrder[$0] ?? .max)
                < (secondaryOrder[$1] ?? .max)
        }
        let directlyRankedSet = Set(directlyRanked)
        let baseRanked = secondaryByText.compactMap {
            text, candidate -> (text: String, rank: Int)? in
            guard !directlyRankedSet.contains(text),
                  let base = candidate.uniqueInflectionBase,
                  let rank = input.inflectionBaseRanks[base.historyKey]
            else { return nil }
            return (text, rank)
        }.sorted {
            if $0.rank != $1.rank { return $0.rank > $1.rank }
            return (secondaryOrder[$0.text] ?? .max)
                < (secondaryOrder[$1.text] ?? .max)
        }.map(\.text)
        let rankedSecondary = directlyRanked + baseRanked
        let effectiveSecondaryRanks = Dictionary(
            uniqueKeysWithValues: rankedSecondary.enumerated().map {
                ($0.element, rankedSecondary.count - $0.offset)
            }
        )
        let orderedTexts = candidates(from: Input(
            kana: input.kana.map(\.storageText),
            direct: input.direct.map(\.storageText),
            secondary: input.secondary.map(\.storageText),
            other: input.other.map(\.storageText),
            english: input.english.map(\.storageText),
            trailing: input.trailing.map(\.storageText),
            recencyRanks: input.recencyRanks,
            secondaryRanks: effectiveSecondaryRanks,
            contextualCandidates: input.contextualCandidates,
            prioritizeKana: input.prioritizeKana,
            includeAutomaticKanaCandidates:
                input.includeAutomaticKanaCandidates
        ))
        let allCandidates = input.kana + input.direct + input.secondary
            + input.other + input.english + input.trailing
        let grouped = Dictionary(grouping: allCandidates, by: \.storageText)
        return orderedTexts.compactMap { text in
            guard let matches = grouped[text],
                  let first = matches.first else { return nil }
            return matches.dropFirst().reduce(first) {
                $0.mergingOrigins(from: $1)
            }
        }
    }

    public func candidates(from input: Input) -> [String] {
        let kana = input.includeAutomaticKanaCandidates
            ? orderedKanaCandidates(
                input.kana,
                matching: input.direct,
                recencyRanks: input.recencyRanks
            )
            : []
        let candidates = CandidatePriorityOrderer.ordered(
            kana: kana,
            direct: input.direct,
            secondary: input.secondary,
            others: input.other + input.english,
            recencyRanks: input.recencyRanks,
            secondaryRanks: input.secondaryRanks,
            contextualCandidates: input.contextualCandidates,
            prioritizeKana: input.includeAutomaticKanaCandidates
                && input.prioritizeKana
        )
        let prioritized = candidates.movingEnglishCandidatesAfterCloseJapaneseCandidates(
            english: input.english,
            closeJapanese: kana + input.direct
        )
        let trailing = input.trailing.removingDuplicates()
        let trailingSet = Set(trailing)
        return prioritized.filter { !trailingSet.contains($0) } + trailing
    }

    private func orderedKanaCandidates(
        _ kana: [String],
        matching dictionaryCandidates: [String],
        recencyRanks: [String: Int]
    ) -> [String] {
        if kana.first?.count == 1 {
            return kana
        }
        let kanaSet = Set(kana)
        var seen = Set<String>()
        let dictionaryKana = dictionaryCandidates.filter {
            kanaSet.contains($0) && seen.insert($0).inserted
        }
        guard !dictionaryKana.isEmpty else {
            return kana
        }
        let preferred = CandidateRecencyOrderer.ordered(
            dictionaryKana,
            ranks: recencyRanks
        )
        let preferredSet = Set(preferred)
        return preferred + kana.filter { !preferredSet.contains($0) }
    }
}

private extension Array where Element == String {
    func removingDuplicates() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }

    func movingEnglishCandidatesAfterCloseJapaneseCandidates(
        english: [String],
        closeJapanese: [String]
    ) -> [String] {
        let englishSet = Set(english)
        guard !englishSet.isEmpty else { return self }

        let closeJapaneseSet = Set(closeJapanese).subtracting(englishSet)
        let englishCandidates = filter { englishSet.contains($0) }
        var otherCandidates = filter { !englishSet.contains($0) }
        guard let lastCloseJapaneseIndex = otherCandidates.lastIndex(where: {
            closeJapaneseSet.contains($0)
        }) else {
            return self
        }

        otherCandidates.insert(
            contentsOf: englishCandidates,
            at: otherCandidates.index(after: lastCloseJapaneseIndex)
        )
        return otherCandidates
    }
}
