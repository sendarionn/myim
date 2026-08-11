public struct CandidatePipeline: Sendable {
    public struct Input: Sendable {
        public let kana: [String]
        public let direct: [String]
        public let other: [String]
        public let recencyRanks: [String: Int]
        public let prioritizeKana: Bool

        public init(
            kana: [String],
            direct: [String],
            other: [String],
            recencyRanks: [String: Int],
            prioritizeKana: Bool
        ) {
            self.kana = kana
            self.direct = direct
            self.other = other
            self.recencyRanks = recencyRanks
            self.prioritizeKana = prioritizeKana
        }
    }

    public init() {}

    public func candidates(from input: Input) -> [String] {
        CandidatePriorityOrderer.ordered(
            kana: input.kana,
            direct: input.direct,
            others: input.other,
            recencyRanks: input.recencyRanks,
            prioritizeKana: input.prioritizeKana
        )
    }
}
