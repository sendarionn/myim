public enum TranslationCandidateChannel: Hashable, Sendable {
    case normal
    case fuzzy

    /// Translation panels extend away from their source: left of normal
    /// candidates and right of fuzzy suggestions
    public var extendsLeft: Bool {
        self == .normal
    }
}

/// A candidate in one language panel; panel 0 is next to the source
public struct TranslationCandidateSelection: Equatable, Sendable {
    public let groupIndex: Int
    public let candidateIndex: Int

    public init(groupIndex: Int, candidateIndex: Int) {
        self.groupIndex = groupIndex
        self.candidateIndex = candidateIndex
    }
}

public enum TranslationPanelMove: Equatable, Sendable {
    case selected(Candidate)
    case returnedToSource
    case unchanged
}

public struct TranslationCandidateSession: Equatable, Sendable {
    private var groupsByChannelAndSource:
        [TranslationCandidateChannel: [String: [TranslationCandidateGroup]]] =
        [:]
    private var sourceOrderByChannel:
        [TranslationCandidateChannel: [String]] = [:]
    private var generatedTextsByChannel:
        [TranslationCandidateChannel: Set<String>] = [:]

    public private(set) var visibleGroups: [TranslationCandidateGroup] = []
    public private(set) var visibleChannel: TranslationCandidateChannel?
    public private(set) var selection: TranslationCandidateSelection?
    public private(set) var returnWasFuzzy = false

    public init() {}

    @discardableResult
    public mutating func store(
        _ groups: [TranslationCandidateGroup],
        for source: String,
        channel: TranslationCandidateChannel
    ) -> [TranslationCandidateGroup] {
        if groupsByChannelAndSource[channel]?[source] == nil {
            sourceOrderByChannel[channel, default: []].append(source)
        }
        groupsByChannelAndSource[channel, default: [:]][source] = groups
        generatedTextsByChannel[channel, default: []].formUnion(
            groups.flatMap(\.candidates).map(\.storageText)
        )
        return groups
    }

    public func groups(
        for source: String,
        channel: TranslationCandidateChannel
    ) -> [TranslationCandidateGroup] {
        groupsByChannelAndSource[channel]?[source] ?? []
    }

    public func sources(
        in channel: TranslationCandidateChannel
    ) -> [String] {
        sourceOrderByChannel[channel] ?? []
    }

    public func contains(
        _ text: String,
        in channel: TranslationCandidateChannel
    ) -> Bool {
        generatedTextsByChannel[channel]?.contains(text) ?? false
    }

    public var hasVisibleCandidates: Bool {
        visibleGroups.contains { !$0.candidates.isEmpty }
    }

    public var selectedCandidate: Candidate? {
        selection.map {
            visibleGroups[$0.groupIndex].candidates[$0.candidateIndex]
        }
    }

    public var selectedTargetIdentifier: String? {
        selection.map { visibleGroups[$0.groupIndex].targetIdentifier }
    }

    /// Replaces the panels; the previous selection does not carry over
    public mutating func show(
        _ groups: [TranslationCandidateGroup],
        channel: TranslationCandidateChannel
    ) {
        visibleGroups = groups.filter { !$0.candidates.isEmpty }
        visibleChannel = visibleGroups.isEmpty ? nil : channel
        selection = nil
    }

    @discardableResult
    public mutating func select(
        _ selection: TranslationCandidateSelection,
        returningToFuzzy: Bool
    ) -> Candidate? {
        guard visibleGroups.indices.contains(selection.groupIndex),
              visibleGroups[selection.groupIndex].candidates.indices.contains(
                selection.candidateIndex
              ) else {
            return nil
        }
        returnWasFuzzy = returningToFuzzy
            || returnWasFuzzy && self.selection != nil
        self.selection = selection
        return selectedCandidate
    }

    /// Moves within the selected language panel, wrapping at either end
    @discardableResult
    public mutating func moveVertically(by offset: Int) -> Candidate? {
        guard let selection else { return nil }
        let count = visibleGroups[selection.groupIndex].candidates.count
        return select(
            TranslationCandidateSelection(
                groupIndex: selection.groupIndex,
                candidateIndex: ((selection.candidateIndex + offset)
                    % count + count) % count
            ),
            returningToFuzzy: returnWasFuzzy
        )
    }

    /// Moves to the neighbouring language panel keeping the row where it
    /// exists; moving toward the source from the first panel leaves the
    /// translation panels
    public mutating func moveHorizontally(movingLeft: Bool) -> TranslationPanelMove {
        guard let selection, let visibleChannel else { return .unchanged }
        let outward = movingLeft == visibleChannel.extendsLeft
        let groupIndex = selection.groupIndex + (outward ? 1 : -1)
        guard groupIndex >= 0 else {
            clearSelection()
            return .returnedToSource
        }
        guard visibleGroups.indices.contains(groupIndex) else {
            return .unchanged
        }
        let lastIndex = visibleGroups[groupIndex].candidates.count - 1
        let candidate = select(
            TranslationCandidateSelection(
                groupIndex: groupIndex,
                candidateIndex: min(selection.candidateIndex, lastIndex)
            ),
            returningToFuzzy: returnWasFuzzy
        )
        return candidate.map(TranslationPanelMove.selected) ?? .unchanged
    }

    public mutating func clearSelection() {
        selection = nil
    }

    public mutating func reset() {
        groupsByChannelAndSource = [:]
        sourceOrderByChannel = [:]
        generatedTextsByChannel = [:]
        visibleGroups = []
        visibleChannel = nil
        selection = nil
        returnWasFuzzy = false
    }
}
