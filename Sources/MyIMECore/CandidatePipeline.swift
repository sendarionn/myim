public struct CandidatePipeline: Sendable {
    public struct Input: Sendable {
        public let kana: [String]
        public let direct: [String]
        public let other: [String]
        public let english: [String]
        public let trailing: [String]
        public let recencyRanks: [String: Int]
        public let contextualCandidates: [String]
        public let prioritizeKana: Bool

        public init(
            kana: [String],
            direct: [String],
            other: [String],
            english: [String] = [],
            trailing: [String] = [],
            recencyRanks: [String: Int],
            contextualCandidates: [String] = [],
            prioritizeKana: Bool
        ) {
            self.kana = kana
            self.direct = direct
            self.other = other
            self.english = english
            self.trailing = trailing
            self.recencyRanks = recencyRanks
            self.contextualCandidates = contextualCandidates
            self.prioritizeKana = prioritizeKana
        }
    }

    public init() {}

    public func candidates(from input: Input) -> [String] {
        let kana = orderedKanaCandidates(
            input.kana,
            matching: input.direct,
            recencyRanks: input.recencyRanks
        )
        let candidates = CandidatePriorityOrderer.ordered(
            kana: kana,
            direct: input.direct,
            others: input.other + input.english,
            recencyRanks: input.recencyRanks,
            contextualCandidates: input.contextualCandidates,
            prioritizeKana: input.prioritizeKana
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
