public enum TranslationCandidateChannel: Hashable, Sendable {
    case normal
    case fuzzy
}

public struct TranslationCandidateSession: Equatable, Sendable {
    private var candidatesByChannelAndSource:
        [TranslationCandidateChannel: [String: [Candidate]]] = [:]
    private var sourceOrderByChannel:
        [TranslationCandidateChannel: [String]] = [:]
    private var generatedTextsByChannel:
        [TranslationCandidateChannel: Set<String>] = [:]

    public private(set) var visibleCandidates: [Candidate] = []
    public private(set) var selectedIndex: Int?
    public private(set) var returnWasFuzzy = false

    public init() {}

    @discardableResult
    public mutating func store(
        _ values: [String],
        for source: String,
        channel: TranslationCandidateChannel
    ) -> [Candidate] {
        let candidates = values.map {
            Candidate(
                storageText: $0,
                source: .translation,
                reading: source,
                attributes: [.generated]
            )
        }
        if candidatesByChannelAndSource[channel]?[source] == nil {
            sourceOrderByChannel[channel, default: []].append(source)
        }
        candidatesByChannelAndSource[channel, default: [:]][source] =
            candidates
        generatedTextsByChannel[channel, default: []].formUnion(values)
        return candidates
    }

    public func candidates(
        for source: String,
        channel: TranslationCandidateChannel
    ) -> [Candidate] {
        candidatesByChannelAndSource[channel]?[source] ?? []
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

    public mutating func show(_ candidates: [Candidate]) {
        visibleCandidates = candidates
    }

    @discardableResult
    public mutating func select(
        index: Int,
        returningToFuzzy: Bool
    ) -> Candidate? {
        guard visibleCandidates.indices.contains(index) else {
            return nil
        }
        returnWasFuzzy = returningToFuzzy
            || returnWasFuzzy && selectedIndex != nil
        selectedIndex = index
        return visibleCandidates[index]
    }

    public mutating func clearSelection() {
        selectedIndex = nil
    }

    public mutating func reset() {
        candidatesByChannelAndSource = [:]
        sourceOrderByChannel = [:]
        generatedTextsByChannel = [:]
        visibleCandidates = []
        selectedIndex = nil
        returnWasFuzzy = false
    }
}
