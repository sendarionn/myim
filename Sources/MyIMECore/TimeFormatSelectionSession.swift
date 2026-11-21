/// How choosing among the formats of a selected time ended
public enum TimeFormatSelectionOutcome: Equatable, Sendable {
    case selected(Int)
    /// Esc goes back to the rail with the same time
    case returnToTime
    /// The panels were closed some other way
    case closed
}

public struct TimeFormatSelectionSession: Equatable, Sendable {
    public private(set) var candidates: [String]?
    public private(set) var selectedIndex: Int?
    public private(set) var isActive = false
    /// The time the formats are made for, kept for going back to the rail
    public private(set) var time: TimeSelectionState?
    /// The range the formats are made for, kept for going back to the rail
    public private(set) var range: TimeRangeSelection?

    public init() {}

    public var isSelectingFormat: Bool { candidates != nil }

    public mutating func beginTimeSelection() {
        candidates = nil
        selectedIndex = nil
        time = nil
        range = nil
        isActive = true
    }

    public mutating func beginFormatLoading(for time: TimeSelectionState) {
        candidates = []
        selectedIndex = nil
        self.time = time
        range = nil
    }

    public mutating func beginFormatLoading(for range: TimeRangeSelection) {
        candidates = []
        selectedIndex = nil
        time = nil
        self.range = range
    }

    /// Whether formats arriving for `range` belong to the current request
    public func accepts(formatsFor range: TimeRangeSelection) -> Bool {
        isActive && isSelectingFormat && self.range == range
    }

    /// Leaves the formats for the rail, returning the range to show again
    public mutating func returnToRangeSelection() -> TimeRangeSelection? {
        guard isActive, let range else { return nil }
        candidates = nil
        selectedIndex = nil
        return range
    }

    /// Whether formats arriving for `time` belong to the current request;
    /// requests made before going back to the rail are stale
    public func accepts(formatsFor time: TimeSelectionState) -> Bool {
        isActive && isSelectingFormat && self.time == time
    }

    /// Leaves the formats for the rail, returning the time to show again
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
        range = nil
        isActive = false
    }
}
