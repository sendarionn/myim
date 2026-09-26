public struct CandidateSelectionState<Value> {
    public var values: [Value]
    public var selectedIndex: Int?

    public init(values: [Value] = [], selectedIndex: Int? = nil) {
        self.values = values
        self.selectedIndex = selectedIndex
    }

    public var selectedValue: Value? {
        guard let selectedIndex,
              values.indices.contains(selectedIndex) else {
            return nil
        }
        return values[selectedIndex]
    }

    public mutating func reset() {
        values = []
        selectedIndex = nil
    }
}

extension CandidateSelectionState: Equatable where Value: Equatable {}
extension CandidateSelectionState: Sendable where Value: Sendable {}
