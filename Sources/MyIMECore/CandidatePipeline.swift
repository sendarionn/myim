public struct CandidatePipeline: Sendable {
    public struct Input: Sendable {
        public let kana: [String]
        public let direct: [String]
        public let other: [String]
        public let english: [String]
        public let recencyRanks: [String: Int]
        public let contextualCandidates: [String]
        public let prioritizeKana: Bool

        public init(
            kana: [String],
            direct: [String],
            other: [String],
            english: [String] = [],
            recencyRanks: [String: Int],
            contextualCandidates: [String] = [],
            prioritizeKana: Bool
        ) {
            self.kana = kana
            self.direct = direct
            self.other = other
            self.english = english
            self.recencyRanks = recencyRanks
            self.contextualCandidates = contextualCandidates
            self.prioritizeKana = prioritizeKana
        }
    }

    public init() {}

    public func candidates(from input: Input) -> [String] {
        let kana = orderedKanaCandidates(
            input.kana,
            matching: input.direct
        )
        let candidates = CandidatePriorityOrderer.ordered(
            kana: kana,
            direct: input.direct,
            others: input.other + input.english,
            recencyRanks: input.recencyRanks,
            contextualCandidates: input.contextualCandidates,
            prioritizeKana: input.prioritizeKana
        )
        return candidates.movingEnglishCandidatesAfterCloseJapaneseCandidates(
            english: input.english,
            closeJapanese: kana + input.direct
        )
    }

    private func orderedKanaCandidates(
        _ kana: [String],
        matching dictionaryCandidates: [String]
    ) -> [String] {
        guard kana.first?.count != 1 else {
            return kana
        }
        let kanaSet = Set(kana)
        guard let preferred = dictionaryCandidates.first(where: {
            kanaSet.contains($0)
        }) else {
            return kana
        }
        return [preferred] + kana.filter { $0 != preferred }
    }
}

private extension Array where Element == String {
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
