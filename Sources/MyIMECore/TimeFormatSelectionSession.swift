/// How choosing among the formats of a selected time ended
public enum TimeFormatSelectionOutcome: Equatable, Sendable {
    case selected(Int)
    /// Esc goes back to the clock with the same time
    case returnToTime
    /// The panels were closed some other way
    case closed
}

public struct TimeFormatSelectionSession: Equatable, Sendable {
    public private(set) var candidates: [String]?
    public private(set) var selectedIndex: Int?
    public private(set) var isActive = false
    /// The time the formats are made for, kept for going back to the clock
    public private(set) var time: TimeSelectionState?

    public init() {}

    public var isSelectingFormat: Bool { candidates != nil }

    public mutating func beginTimeSelection() {
        candidates = nil
        selectedIndex = nil
        time = nil
        isActive = true
    }

    public mutating func beginFormatLoading(for time: TimeSelectionState) {
        candidates = []
        selectedIndex = nil
        self.time = time
    }

    /// Whether formats arriving for `time` belong to the current request;
    /// requests made before going back to the clock are stale
    public func accepts(formatsFor time: TimeSelectionState) -> Bool {
        isActive && isSelectingFormat && self.time == time
    }

    /// Leaves the formats for the clock, returning the time to show again
    public mutating func returnToTimeSelection() -> TimeSelectionState? {
        guard isActive, let time else { return nil }
        candidates = nil
        selectedIndex = nil
        return time
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
        time = nil
        isActive = false
    }
}
