public struct CalendarFormatCandidate: Equatable, Sendable {
    public let value: String
    public let preferenceID: String?

    public init(value: String, preferenceID: String? = nil) {
        self.value = value
        self.preferenceID = preferenceID
    }
}

public struct CalendarFormatSelectionSession: Equatable, Sendable {
    public private(set) var candidates: [CalendarFormatCandidate]?
    public private(set) var selectedIndex: Int?
    public private(set) var isActive = false

    public init() {}

    public var isSelectingFormat: Bool {
        candidates != nil
    }

    public var selectedCandidate: CalendarFormatCandidate? {
        guard let candidates, let selectedIndex,
              candidates.indices.contains(selectedIndex) else {
            return nil
        }
        return candidates[selectedIndex]
    }

    public mutating func beginCalendarSelection() {
        candidates = nil
        selectedIndex = nil
        isActive = true
    }

    public mutating func beginFormatLoading() {
        candidates = []
        selectedIndex = nil
    }

    public mutating func replaceCandidates(
        _ candidates: [CalendarFormatCandidate],
        ranks: [String: Int] = [:]
    ) {
        let preferenceIDs = candidates.map { $0.preferenceID ?? "" }
        self.candidates = CandidateRecencyOrderer.orderedIndices(
            preferenceIDs,
            ranks: ranks
        ).map { candidates[$0] }
        selectedIndex = nil
    }

    public mutating func select(index: Int?) {
        guard let index else {
            selectedIndex = nil
            return
        }
        guard let candidates, candidates.indices.contains(index) else {
            return
        }
        selectedIndex = index
    }

    @discardableResult
    public mutating func moveSelection(by offset: Int) -> Int? {
        guard let candidates else { return nil }
        let nextIndex = LinearCandidateNavigator.index(
            from: selectedIndex,
            offset: offset,
            candidateCount: candidates.count
        )
        selectedIndex = nextIndex
        return nextIndex
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
