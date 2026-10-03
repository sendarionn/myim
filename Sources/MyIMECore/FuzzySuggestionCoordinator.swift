public struct FuzzySuggestion: Equatable, Sendable {
    public let candidate: String
    public let reading: String
    public let distance: Int
    public let isLearnable: Bool

    public init(
        candidate: String,
        reading: String,
        distance: Int,
        isLearnable: Bool = true
    ) {
        self.candidate = candidate
        self.reading = reading
        self.distance = distance
        self.isLearnable = isLearnable
    }
}

public struct FuzzySuggestionPage: Equatable, Sendable {
    public let suggestions: [FuzzySuggestion]
    public let selectedIndex: Int?

    public init(
        suggestions: [FuzzySuggestion],
        selectedIndex: Int?
    ) {
        self.suggestions = suggestions
        self.selectedIndex = selectedIndex
    }
}

public struct FuzzySuggestionCoordinator: Equatable, Sendable {
    private var selection: CandidateSelectionState<FuzzySuggestion>

    public init(suggestions: [FuzzySuggestion] = []) {
        selection = CandidateSelectionState(values: suggestions)
    }

    public var suggestions: [FuzzySuggestion] {
        selection.values
    }

    public var selectedIndex: Int? {
        selection.selectedIndex
    }

    public var selectedSuggestion: FuzzySuggestion? {
        selection.selectedValue
    }

    public var isEmpty: Bool {
        selection.values.isEmpty
    }

    @discardableResult
    public mutating func replace(
        matchTiers: [[FuzzyConversionMatch]],
        recencyRanks: [String: Int],
        preserveSelectionWhenUnchanged: Bool = false
    ) -> Bool {
        let suggestionTiers = matchTiers.map { matches in
            matches.compactMap { match in
                match.candidates.first.map {
                    FuzzySuggestion(
                        candidate: $0,
                        reading: match.reading,
                        distance: match.distance
                    )
                }
            }
        }
        let orderedTierIndices = TieredCandidateOrderer.orderedIndices(
            for: suggestionTiers.map { $0.map(\.candidate) },
            ranks: recencyRanks
        )
        var seenCandidates = Set<String>()
        let updatedSuggestions = zip(
            suggestionTiers,
            orderedTierIndices
        ).flatMap { suggestions, indices in
            indices.compactMap { index in
                let suggestion = suggestions[index]
                return seenCandidates.insert(suggestion.candidate).inserted
                    ? suggestion
                    : nil
            }
        }
        let changed = selection.values != updatedSuggestions
        if !changed, preserveSelectionWhenUnchanged {
            return false
        }
        selection.values = updatedSuggestions
        selection.selectedIndex = nil
        return changed
    }

    @discardableResult
    public mutating func select(index: Int?) -> FuzzySuggestion? {
        guard let index else {
            selection.selectedIndex = nil
            return nil
        }
        guard selection.values.indices.contains(index) else { return nil }
        let candidate = selection.values[index].candidate
        guard let resolvedIndex = selection.values.firstIndex(where: {
            $0.candidate == candidate
        }) else { return nil }
        selection.selectedIndex = resolvedIndex
        return selection.values[resolvedIndex]
    }

    @discardableResult
    public mutating func select(candidate: String) -> FuzzySuggestion? {
        guard let index = selection.values.firstIndex(where: {
            $0.candidate == candidate
        }) else { return nil }
        return select(index: index)
    }

    public func indexAlignedWithNormalCandidate(
        normalSelectedIndex: Int?,
        maximumCount: Int
    ) -> Int? {
        guard !selection.values.isEmpty, maximumCount > 0 else { return nil }
        let normalRow = normalSelectedIndex.map { $0 % maximumCount } ?? 0
        return min(normalRow, selection.values.count - 1)
    }

    public func normalCandidateIndexAlignedWithSelection(
        normalCandidateCount: Int,
        currentNormalIndex: Int?,
        maximumCount: Int
    ) -> Int? {
        guard let selectedIndex = selection.selectedIndex,
              normalCandidateCount > 0,
              maximumCount > 0 else { return nil }
        let fuzzyRow = selectedIndex % maximumCount
        let pageStart = (currentNormalIndex ?? 0)
            / maximumCount
            * maximumCount
        let pageEnd = min(pageStart + maximumCount, normalCandidateCount)
        return min(pageStart + fuzzyRow, pageEnd - 1)
    }

    public func index(after offset: Int) -> Int? {
        LinearCandidateNavigator.index(
            from: selection.selectedIndex,
            offset: offset,
            candidateCount: selection.values.count
        )
    }

    public func initialPage(maximumCount: Int) -> FuzzySuggestionPage? {
        guard !selection.values.isEmpty, maximumCount > 0 else { return nil }
        return FuzzySuggestionPage(
            suggestions: Array(selection.values.prefix(maximumCount)),
            selectedIndex: nil
        )
    }

    public func selectedPage(maximumCount: Int) -> FuzzySuggestionPage? {
        guard let selectedIndex = selection.selectedIndex,
              selection.values.indices.contains(selectedIndex),
              maximumCount > 0 else { return nil }
        let pageStart = selectedIndex / maximumCount * maximumCount
        let pageEnd = min(
            pageStart + maximumCount,
            selection.values.count
        )
        return FuzzySuggestionPage(
            suggestions: Array(selection.values[pageStart..<pageEnd]),
            selectedIndex: selectedIndex - pageStart
        )
    }

    public mutating func reset() {
        selection.reset()
    }
}
