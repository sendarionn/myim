public struct CandidatePipeline: Sendable {
    public struct Input: Sendable {
        public let kana: [String]
        public let direct: [String]
        public let other: [String]
        public let recencyRanks: [String: Int]
        public let contextualCandidates: [String]
        public let prioritizeKana: Bool

        public init(
            kana: [String],
            direct: [String],
            other: [String],
            recencyRanks: [String: Int],
            contextualCandidates: [String] = [],
            prioritizeKana: Bool
        ) {
            self.kana = kana
            self.direct = direct
            self.other = other
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
        return CandidatePriorityOrderer.ordered(
            kana: kana,
            direct: input.direct,
            others: input.other,
            recencyRanks: input.recencyRanks,
            contextualCandidates: input.contextualCandidates,
            prioritizeKana: input.prioritizeKana
        )
    }

    private func orderedKanaCandidates(
        _ kana: [String],
        matching dictionaryCandidates: [String]
    ) -> [String] {
        let kanaSet = Set(kana)
        guard let preferred = dictionaryCandidates.first(where: {
            kanaSet.contains($0)
        }) else {
            return kana
        }
        return [preferred] + kana.filter { $0 != preferred }
    }
}
