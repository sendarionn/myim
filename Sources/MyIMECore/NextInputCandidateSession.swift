public struct NextInputCandidateSession: Equatable, Sendable {
    public private(set) var candidateModels: [Candidate] = []
    public private(set) var context: String?
    public private(set) var selectedIndex: Int?

    public init() {}

    public var candidates: [String] {
        candidateModels.map(\.displayText)
    }

    public var selectedCandidateModel: Candidate? {
        guard let selectedIndex,
              candidateModels.indices.contains(selectedIndex) else {
            return nil
        }
        return candidateModels[selectedIndex]
    }

    public var selectedCandidate: String? {
        selectedCandidateModel?.commitText
    }

    public mutating func begin(context: String, candidates: [String]) {
        begin(
            context: context,
            candidates: candidates.map { Candidate(storageText: $0) }
        )
    }

    public mutating func begin(context: String, candidates: [Candidate]) {
        self.context = context
        candidateModels = candidates
        selectedIndex = nil
    }

    public mutating func updateCandidates(_ candidates: [String]) {
        updateCandidates(candidates.map { Candidate(storageText: $0) })
    }

    public mutating func updateCandidates(_ candidates: [Candidate]) {
        let selectedModel = selectedCandidateModel
        candidateModels = candidates
        if let selectedModel {
            selectedIndex = candidates.firstIndex(of: selectedModel)
                ?? candidates.firstIndex {
                    $0.commitText == selectedModel.commitText
                }
        } else if selectedIndex != nil {
            selectedIndex = nil
        }
    }

    public mutating func clearCandidates() {
        candidateModels = []
        selectedIndex = nil
    }

    @discardableResult
    public mutating func select(index: Int) -> String? {
        guard candidateModels.indices.contains(index) else { return nil }
        selectedIndex = index
        return candidateModels[index].commitText
    }

    public func linearSelectionIndex(offset: Int) -> Int? {
        return LinearCandidateNavigator.index(
            from: selectedIndex,
            offset: offset,
            candidateCount: candidateModels.count
        )
    }

    public func wrappedSelectionIndex(offset: Int) -> Int? {
        guard !candidateModels.isEmpty else { return nil }
        let currentIndex = selectedIndex ?? (offset > 0 ? -1 : 0)
        return (
            currentIndex + offset + candidateModels.count
        ) % candidateModels.count
    }

    @discardableResult
    public mutating func removeSelectedCandidate() -> String? {
        guard let selectedIndex,
              candidateModels.indices.contains(selectedIndex) else {
            return nil
        }
        let removed = candidateModels.remove(at: selectedIndex)
        self.selectedIndex = nil
        return removed.commitText
    }

    public mutating func reset() {
        candidateModels = []
        context = nil
        selectedIndex = nil
    }
}
