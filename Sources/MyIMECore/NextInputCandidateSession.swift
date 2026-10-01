public struct NextInputCandidateSession: Equatable, Sendable {
    public private(set) var candidates: [String] = []
    public private(set) var context: String?
    public private(set) var selectedIndex: Int?

    public init() {}

    public var selectedCandidate: String? {
        guard let selectedIndex,
              candidates.indices.contains(selectedIndex) else {
            return nil
        }
        return candidates[selectedIndex]
    }

    public mutating func begin(context: String, candidates: [String]) {
        self.context = context
        self.candidates = candidates
        selectedIndex = nil
    }

    public mutating func updateCandidates(_ candidates: [String]) {
        let selectedCandidate = selectedCandidate
        self.candidates = candidates
        if let selectedCandidate {
            selectedIndex = candidates.firstIndex(of: selectedCandidate)
        } else if selectedIndex != nil {
            selectedIndex = nil
        }
    }

    public mutating func clearCandidates() {
        candidates = []
        selectedIndex = nil
    }

    @discardableResult
    public mutating func select(index: Int) -> String? {
        guard candidates.indices.contains(index) else { return nil }
        selectedIndex = index
        return candidates[index]
    }

    public func linearSelectionIndex(offset: Int) -> Int? {
        return LinearCandidateNavigator.index(
            from: selectedIndex,
            offset: offset,
            candidateCount: candidates.count
        )
    }

    public func wrappedSelectionIndex(offset: Int) -> Int? {
        guard !candidates.isEmpty else { return nil }
        let currentIndex = selectedIndex ?? (offset > 0 ? -1 : 0)
        return (
            currentIndex + offset + candidates.count
        ) % candidates.count
    }

    @discardableResult
    public mutating func removeSelectedCandidate() -> String? {
        guard let selectedIndex,
              candidates.indices.contains(selectedIndex) else {
            return nil
        }
        let removed = candidates.remove(at: selectedIndex)
        self.selectedIndex = nil
        return removed
    }

    public mutating func reset() {
        candidates = []
        context = nil
        selectedIndex = nil
    }
}
