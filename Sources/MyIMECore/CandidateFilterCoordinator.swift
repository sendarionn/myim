public enum CandidateFilterEscapeAction: Equatable, Sendable {
    case inactive
    case refreshDraftChoices
    case showFilteredCandidates
    case restoreUnfilteredCandidates
    case cancelDraft
}

public struct CandidateFilterDraftPage: Equatable, Sendable {
    public let choices: [CandidateFilterDraftChoice]
    public let selectedIndex: Int?

    public init(
        choices: [CandidateFilterDraftChoice],
        selectedIndex: Int?
    ) {
        self.choices = choices
        self.selectedIndex = selectedIndex
    }
}

public struct CandidateFilterCoordinator: Sendable {
    private var session = CandidateFilterInputSession()

    public init() {}

    public var draft: CandidateFilterDraft? {
        session.draft
    }

    public var conditions: [CandidateFilterCondition] {
        session.conditions
    }

    public var conditionLabels: [String] {
        session.conditions.map(\.label)
    }

    public mutating func beginDraft() {
        session.beginDraft()
    }

    public mutating func appendToDraft(_ value: String) {
        session.appendToDraft(value)
    }

    @discardableResult
    public mutating func deleteBackwardFromDraft() -> Bool {
        session.deleteBackwardFromDraft()
    }

    @discardableResult
    public mutating func moveDraftSelection(by offset: Int) -> Bool {
        session.moveDraftSelection(by: offset)
    }

    @discardableResult
    public mutating func enterFilterStageForDirectInput(
        queryVariants: [String]
    ) -> Bool {
        guard let draft = session.draft,
              draft.stage == .conversion,
              draft.selectedIndex == nil,
              CandidateFilterInputConfirmationPolicy.canConfirmDirectly(
                  input: draft.input,
                  queryVariants: queryVariants
              ) else {
            return false
        }
        session.enterFilterStage()
        return true
    }

    public mutating func refreshChoices(
        queryVariants: (String) -> [String],
        choiceGenerator: CandidateFilterChoiceGenerator
    ) {
        guard let draft = session.draft else { return }
        var choices: [CandidateFilterDraftChoice] = []
        var seen = Set<String>()
        if draft.input.isEmpty {
            choices = []
        } else if draft.stage == .filter {
            for choice in choiceGenerator.choices(
                for: draft.input,
                activeConditions: session.conditions
            ) where seen.insert(choice.label).inserted {
                choices.append(.filter(choice))
            }
        } else {
            let variants = queryVariants(draft.input)
            let conversionCandidates = variants.count > 1
                ? variants.dropFirst()
                : variants[...]
            for convertedInput in conversionCandidates
            where seen.insert(convertedInput).inserted {
                choices.append(.input(convertedInput))
            }
        }
        session.updateDraftChoices(choices)
    }

    public mutating func applySelectedChoice()
        -> CandidateFilterSelectionResult? {
        session.applySelectedChoice()
    }

    public mutating func escape(
        hasUnfilteredCandidates: Bool
    ) -> CandidateFilterEscapeAction {
        guard session.draft != nil else { return .inactive }
        if session.returnToConversionStage() {
            return .refreshDraftChoices
        }
        return removeLastCondition(
            hasUnfilteredCandidates: hasUnfilteredCandidates
        )
    }

    public mutating func removeLastCondition(
        hasUnfilteredCandidates: Bool
    ) -> CandidateFilterEscapeAction {
        guard hasUnfilteredCandidates else {
            session.cancelDraft()
            return .cancelDraft
        }
        _ = session.removeLastCondition()
        return session.conditions.isEmpty
            ? .restoreUnfilteredCandidates
            : .showFilteredCandidates
    }

    public func visibleDraftPage(
        maximumCount: Int
    ) -> CandidateFilterDraftPage? {
        guard let draft = session.draft, maximumCount > 0 else { return nil }
        let selectedIndex = draft.selectedIndex ?? 0
        let pageStart = selectedIndex / maximumCount * maximumCount
        let pageEnd = min(pageStart + maximumCount, draft.choices.count)
        let choices = pageStart < pageEnd
            ? Array(draft.choices[pageStart..<pageEnd])
            : []
        return CandidateFilterDraftPage(
            choices: choices,
            selectedIndex: draft.selectedIndex.map { $0 - pageStart }
        )
    }

    public func filteredCandidates(
        _ candidates: [String],
        using filter: CandidateFilter,
        semanticScorer: CandidateFilter.SemanticScorer? = nil
    ) -> [String] {
        filter.filtered(
            candidates,
            conditions: session.conditions,
            semanticScorer: semanticScorer
        )
    }

    public mutating func reset() {
        session.reset()
    }
}
