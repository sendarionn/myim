public struct CandidateSession: Equatable, Sendable {
    private var selection = CandidateSelectionState<Candidate>()
    public private(set) var unfilteredCandidates: [Candidate]?

    public init() {}

    public var candidates: [Candidate] {
        get { selection.values }
        set { selection.values = newValue }
    }

    public var candidateTexts: [String] {
        selection.values.map(\.storageText)
    }

    public var selectedIndex: Int? {
        get { selection.selectedIndex }
        set { selection.selectedIndex = newValue }
    }

    public var selectedCandidate: Candidate? {
        selection.selectedValue
    }

    public mutating func reset() {
        selection.reset()
    }

    public mutating func replace(
        with candidates: [Candidate],
        input: String,
        reading: String
    ) {
        let selectedText = selectedCandidate?.storageText
        let byText = Dictionary(
            candidates.map { ($0.storageText, $0) },
            uniquingKeysWith: { first, second in
                first.mergingOrigins(from: second)
            }
        )
        let texts = candidates.map(\.storageText)
        let protected = Set(candidates.filter {
            $0.hasAttribute(.preservesLongVowelNotation)
        }.map(\.storageText))
        let matched = input == "-"
            ? texts
            : LongVowelNotationCandidateFilter.candidates(
                texts,
                for: reading,
                preserving: protected
            )
        var orderedTexts = matched
        if input == "-", let index = orderedTexts.firstIndex(of: "ー") {
            orderedTexts.remove(at: index)
            orderedTexts.insert("ー", at: 0)
        }
        selection.values = orderedTexts.compactMap { byText[$0] }
        if let selectedText {
            selection.selectedIndex = selection.values.firstIndex {
                $0.storageText == selectedText
            }
        } else if selection.selectedIndex != nil {
            selection.selectedIndex = nil
        }
    }

    public mutating func insert(_ candidate: Candidate, at index: Int) {
        selection.values.insert(candidate, at: index)
    }

    public mutating func beginFiltering() {
        if unfilteredCandidates == nil {
            unfilteredCandidates = selection.values
        }
    }

    public mutating func applyFilteredTexts(_ texts: [String]) {
        guard let unfilteredCandidates else { return }
        let byText = Dictionary(
            unfilteredCandidates.map { ($0.storageText, $0) },
            uniquingKeysWith: { first, second in
                first.mergingOrigins(from: second)
            }
        )
        selection.values = texts.compactMap { byText[$0] }
        selection.selectedIndex = nil
    }

    @discardableResult
    public mutating func restoreUnfilteredCandidates() -> Bool {
        guard let unfilteredCandidates else { return false }
        selection.values = unfilteredCandidates
        selection.selectedIndex = nil
        return true
    }

    public mutating func clearFilterBackup() {
        unfilteredCandidates = nil
    }
}
