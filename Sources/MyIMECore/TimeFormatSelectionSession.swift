public struct TimeFormatSelectionSession: Equatable, Sendable {
    public private(set) var candidates: [String]?
    public private(set) var selectedIndex: Int?
    public private(set) var isActive = false

    public init() {}

    public var isSelectingFormat: Bool { candidates != nil }

    public mutating func beginTimeSelection() {
        candidates = nil
        selectedIndex = nil
        isActive = true
    }

    public mutating func beginFormatLoading() {
        candidates = []
        selectedIndex = nil
    }

    public mutating func replaceCandidates(_ values: [String]) {
        candidates = values
        selectedIndex = nil
    }

    public mutating func select(index: Int?) {
        guard let index else {
            selectedIndex = nil
            return
        }
        guard let candidates, candidates.indices.contains(index) else { return }
        selectedIndex = index
    }

    @discardableResult
    public mutating func moveSelection(by offset: Int) -> Int? {
        guard let candidates else { return nil }
        selectedIndex = LinearCandidateNavigator.index(
            from: selectedIndex,
            offset: offset,
            candidateCount: candidates.count
        )
        return selectedIndex
    }

    public func pageRange(pageSize: Int) -> Range<Int> {
        LinearCandidateNavigator.pageRange(
            containing: selectedIndex,
            pageSize: pageSize,
            candidateCount: candidates?.count ?? 0
        )
    }

    public mutating func reset() {
        candidates = nil
        selectedIndex = nil
        isActive = false
    }
}
