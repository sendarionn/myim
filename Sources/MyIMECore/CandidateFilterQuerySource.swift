public struct CandidateFilterQuerySource: Sendable {
    private let userEngine: LayeredConversionEngine
    private let basicEngine: ConversionEngine
    private let systemEngine: IndexedDictionaryEngine
    private let romajiConverter = RomajiConverter()

    public init(
        userEngine: LayeredConversionEngine,
        basicEngine: ConversionEngine,
        systemEngine: IndexedDictionaryEngine
    ) {
        self.userEngine = userEngine
        self.basicEngine = basicEngine
        self.systemEngine = systemEngine
    }

    public func candidates(
        for input: String,
        selectionHistory: CandidateSelectionHistory
    ) -> [String] {
        guard !input.isEmpty else { return [""] }
        let kana = [
            romajiConverter.hiragana(from: input),
            romajiConverter.katakana(from: input)
        ].compactMap { $0 }
        var direct: [String] = []
        for reading in RomajiCanonicalizer.dictionaryLookupInputs(
            from: input
        ) {
            direct.append(contentsOf: userEngine.candidates(for: reading))
            direct.append(contentsOf: basicEngine.candidates(for: reading))
            direct.append(contentsOf: systemEngine.candidates(for: reading))
        }
        let ordered = CandidatePriorityOrderer.ordered(
            kana: kana,
            direct: direct,
            others: [],
            recencyRanks: selectionHistory.ranks(for: input),
            prioritizeKana: kana.first?.count == 1
        )
        var seen = Set<String>()
        return ([input] + ordered).filter {
            !$0.isEmpty && seen.insert($0).inserted
        }
    }
}
