public struct FuzzyCandidate: Equatable, Sendable {
    public let candidate: String
    public let reading: String
    public let distance: Int
    public let isLearnable: Bool
    public let sourceTokens: [String]
    public let sourceReadings: [String?]

    public init(
        candidate: String,
        reading: String,
        distance: Int,
        isLearnable: Bool = true,
        sourceTokens: [String] = [],
        sourceReadings: [String?] = []
    ) {
        self.candidate = candidate
        self.reading = reading
        self.distance = distance
        self.isLearnable = isLearnable
        self.sourceTokens = sourceTokens
        self.sourceReadings = sourceReadings
    }
}

public struct UserDictionaryRegistration: Equatable, Sendable {
    public let reading: String
    public let candidate: String

    public init(reading: String, candidate: String) {
        self.reading = reading
        self.candidate = candidate
    }
}

extension FuzzyCandidate {
    /// Entry saved when the user commits this candidate; a learned phrase
    /// is saved with the whole reading of its units, never the partial
    /// input it was found from, and not at all while a reading is missing
    public var userDictionaryEntry: UserDictionaryRegistration? {
        guard !sourceTokens.isEmpty else {
            return isLearnable
                ? UserDictionaryRegistration(
                    reading: reading,
                    candidate: candidate
                )
                : nil
        }
        let readings = sourceReadings.compactMap { $0 }
        guard readings.count == sourceTokens.count,
              readings.allSatisfy({ !$0.isEmpty }),
              sourceTokens.joined() == candidate else {
            return nil
        }
        return UserDictionaryRegistration(
            reading: readings.joined(),
            candidate: candidate
        )
    }
}

public struct FuzzyCandidatePage: Equatable, Sendable {
    public let candidates: [FuzzyCandidate]
    public let selectedIndex: Int?

    public init(
        candidates: [FuzzyCandidate],
        selectedIndex: Int?
    ) {
        self.candidates = candidates
        self.selectedIndex = selectedIndex
    }
}

public struct FuzzyCandidateSession: Equatable, Sendable {
    private var selection: CandidateSelectionState<FuzzyCandidate>

    public init(candidates: [FuzzyCandidate] = []) {
        selection = CandidateSelectionState(values: candidates)
    }

    public var candidates: [FuzzyCandidate] {
        selection.values
    }

    public var selectedIndex: Int? {
        selection.selectedIndex
    }

    public var selectedCandidate: FuzzyCandidate? {
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
                    FuzzyCandidate(
                        candidate: $0,
                        reading: match.reading,
                        distance: match.distance,
                        isLearnable: match.isLearnable,
                        sourceTokens: match.sourceTokens,
                        sourceReadings: match.sourceReadings
                    )
                }
            }
        }
        let orderedTierIndices = TieredCandidateOrderer.orderedIndices(
            for: suggestionTiers.map { $0.map(\.candidate) },
            ranks: recencyRanks
        )
        var seenCandidates = Set<String>()
        let updatedCandidates = zip(
            suggestionTiers,
            orderedTierIndices
        ).flatMap { candidates, indices in
            indices.compactMap { index in
                let suggestion = candidates[index]
                return seenCandidates.insert(suggestion.candidate).inserted
                    ? suggestion
                    : nil
            }
        }
        let changed = selection.values != updatedCandidates
        if !changed, preserveSelectionWhenUnchanged {
            return false
        }
        selection.values = updatedCandidates
        selection.selectedIndex = nil
        return changed
    }

    @discardableResult
    public mutating func select(index: Int?) -> FuzzyCandidate? {
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
    public mutating func select(candidate: String) -> FuzzyCandidate? {
        guard let index = selection.values.firstIndex(where: {
            $0.candidate == candidate
        }) else { return nil }
        return select(index: index)
    }

    public func indexAlignedWithStandardCandidate(
        standardSelectedIndex: Int?,
        maximumCount: Int
    ) -> Int? {
        guard !selection.values.isEmpty, maximumCount > 0 else { return nil }
        let normalRow = standardSelectedIndex.map { $0 % maximumCount } ?? 0
        return min(normalRow, selection.values.count - 1)
    }

    public func standardCandidateIndexAlignedWithSelection(
        standardCandidateCount: Int,
        currentNormalIndex: Int?,
        maximumCount: Int
    ) -> Int? {
        guard let selectedIndex = selection.selectedIndex,
              standardCandidateCount > 0,
              maximumCount > 0 else { return nil }
        let fuzzyRow = selectedIndex % maximumCount
        let pageStart = (currentNormalIndex ?? 0)
            / maximumCount
            * maximumCount
        let pageEnd = min(pageStart + maximumCount, standardCandidateCount)
        return min(pageStart + fuzzyRow, pageEnd - 1)
    }

    public func index(after offset: Int) -> Int? {
        LinearCandidateNavigator.index(
            from: selection.selectedIndex,
            offset: offset,
            candidateCount: selection.values.count
        )
    }

    public func initialPage(maximumCount: Int) -> FuzzyCandidatePage? {
        guard !selection.values.isEmpty, maximumCount > 0 else { return nil }
        return FuzzyCandidatePage(
            candidates: Array(selection.values.prefix(maximumCount)),
            selectedIndex: nil
        )
    }

    public func selectedPage(maximumCount: Int) -> FuzzyCandidatePage? {
        guard let selectedIndex = selection.selectedIndex,
              selection.values.indices.contains(selectedIndex),
              maximumCount > 0 else { return nil }
        let pageStart = selectedIndex / maximumCount * maximumCount
        let pageEnd = min(
            pageStart + maximumCount,
            selection.values.count
        )
        return FuzzyCandidatePage(
            candidates: Array(selection.values[pageStart..<pageEnd]),
            selectedIndex: selectedIndex - pageStart
        )
    }

    public mutating func reset() {
        selection.reset()
    }
}
