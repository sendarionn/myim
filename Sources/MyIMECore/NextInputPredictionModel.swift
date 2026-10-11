import Foundation

public enum NextInputLearningSource: String, Codable, Sendable {
    case directInput
    case acceptedSuggestion
}

public struct NextInputLearningToken: Equatable, Sendable {
    public let text: String
    public let reading: String?

    public init(text: String, reading: String? = nil) {
        self.text = text
        self.reading = reading
    }
}

public struct NextInputPrediction: Equatable, Sendable {
    public let text: String
    public let sourceTokens: [String]
    public let sourceReadings: [String?]

    public init(
        text: String,
        sourceTokens: [String],
        sourceReadings: [String?] = []
    ) {
        self.text = text
        self.sourceTokens = sourceTokens
        self.sourceReadings = sourceReadings
    }
}

public struct LearnedCompoundPrediction: Equatable, Sendable {
    public let text: String
    public let reading: String
    public let sourceTokens: [String]
    public let sourceReadings: [String?]

    public init(
        text: String,
        reading: String,
        sourceTokens: [String],
        sourceReadings: [String?]
    ) {
        self.text = text
        self.reading = reading
        self.sourceTokens = sourceTokens
        self.sourceReadings = sourceReadings
    }
}

public enum NextInputCandidateMetadata {
    public static let sourceTokensKey = "nextInput.sourceTokens"
    public static let sourceReadingsKey = "nextInput.sourceReadings"
    public static let acceptedSuggestionKey = "nextInput.acceptedSuggestion"

    public static func candidate(from prediction: NextInputPrediction) -> Candidate {
        Candidate(
            storageText: prediction.text,
            source: .nextInput,
            contextualMetadata: [
                sourceTokensKey: encodedTokens(prediction.sourceTokens),
                sourceReadingsKey: encodedReadings(prediction.sourceReadings),
                acceptedSuggestionKey: "true"
            ]
        )
    }

    public static func sourceTokens(from candidate: Candidate) -> [String]? {
        guard
            let encoded = candidate.contextualMetadata[sourceTokensKey],
            let data = Data(base64Encoded: encoded),
            let tokens = try? JSONDecoder().decode([String].self, from: data),
            !tokens.isEmpty
        else {
            return nil
        }
        return tokens
    }

    public static func sourceReadings(from candidate: Candidate) -> [String?]? {
        guard
            let encoded = candidate.contextualMetadata[sourceReadingsKey],
            let data = Data(base64Encoded: encoded),
            let readings = try? JSONDecoder().decode(
                [String?].self,
                from: data
            ),
            !readings.isEmpty
        else {
            return nil
        }
        return readings
    }

    public static func isAcceptedSuggestion(_ candidate: Candidate) -> Bool {
        candidate.contextualMetadata[acceptedSuggestionKey] == "true"
    }

    private static func encodedTokens(_ tokens: [String]) -> String {
        (try? JSONEncoder().encode(tokens).base64EncodedString()) ?? ""
    }

    private static func encodedReadings(_ readings: [String?]) -> String {
        guard !readings.isEmpty else { return "" }
        return (try? JSONEncoder().encode(readings).base64EncodedString()) ?? ""
    }
}

/// Typing context of one input client: the recent commits and the current
/// run of accepted suggestions
///
/// Learned statistics are shared by every client, while each client keeps
/// its own cursor so commits in different apps are not joined into one
/// sequence
public struct NextInputSequenceCursor: Sendable {
    fileprivate var recentInputs: [String] = []
    fileprivate var recentReadings: [String?] = []
    fileprivate var recentSources: [NextInputLearningSource] = []
    fileprivate var episode: NextInputPredictionModel.SuggestionEpisode?
    public fileprivate(set) var lastInput: String?

    public init() {}
}

public struct NextInputPredictionModel: Codable, Sendable {
    public static let maximumContextCount = 2_048
    public static let maximumFollowersPerContext = 16
    public static let maximumSuppressedCandidateCount = 1_024
    public static let maximumValueLength = 80
    public static let maximumContextTokenCount = 4
    public static let maximumPredictionTokenCount = 4
    public static let minimumDirectSequenceCount = 3
    public static let minimumLearnedCompoundPrefixLength = 3
    public static let maximumLearnedCompoundCandidateCount = 4
    /// Selecting the same run of suggestions this many times combines it
    public static let minimumEpisodePromotionCount = 2

    private struct CandidateStat: Codable, Sendable {
        var count: Int
        var lastUsed: Int
    }

    private struct Context: Codable, Sendable {
        var candidates: [String: CandidateStat]
        var lastUsed: Int
    }

    private struct SequenceCandidateStat: Codable, Sendable {
        var tokens: [String]
        var readings: [String?]?
        var directCount: Int
        /// For a multi-token candidate this counts selection episodes only,
        /// since sentence spans containing accepted tokens are not recorded
        var acceptedSuggestionCount: Int
        var lastUsed: Int
    }

    private struct LearnedPhraseStat: Codable, Sendable {
        var tokens: [String]
        var readings: [String?]
        var directCount: Int
        var acceptedSuggestionCount: Int
        var lastUsed: Int
    }

    private struct SequenceContext: Codable, Sendable {
        var candidates: [String: SequenceCandidateStat]
        var occurrenceCount: Int
        var lastUsed: Int
    }

    /// Consecutively accepted suggestions after `context`
    ///
    /// Sentence history keeps every committed token, while an episode keeps
    /// only what the user accepted from suggestions in one run, so the next
    /// direct input is never appended to it
    fileprivate struct SuggestionEpisode: Sendable {
        let context: [String]
        let contextReadings: [String?]
        var tokens: [String]
        var readings: [String?]
        var selectionCount: Int
    }

    private struct RankedPrediction {
        let prediction: NextInputPrediction
        let lastUsed: Int
        let contextLength: Int
    }

    // `contexts` keeps the existing one-token history schema readable
    private var contexts: [String: Context] = [:]
    private var sequenceContexts: [String: SequenceContext] = [:]
    private var learnedPhrases: [String: LearnedPhraseStat] = [:]
    private var learnedPhrasePrefixIndex: [String: Set<String>] = [:]
    private var suppressedCandidates: [String] = []
    private var recentInputs: [String] = []
    private var recentReadings: [String?] = []
    private var recentSources: [NextInputLearningSource] = []
    private var episode: SuggestionEpisode?
    /// Multi-token statistics before version 2 counted windows across
    /// repetitions with the source of the last token only
    private static let sequenceSchemaVersion = 2
    private var sequence = 0
    public private(set) var lastInput: String?

    public init() {}

    public mutating func record(
        _ value: String,
        source: NextInputLearningSource = .directInput
    ) {
        record(tokens: [value], source: source)
    }

    /// `tokens` are one commit; accepted suggestions passed together count
    /// as one selection
    public mutating func record(
        tokens: [String],
        source: NextInputLearningSource = .directInput
    ) {
        record(
            learningTokens: tokens.map { NextInputLearningToken(text: $0) },
            source: source
        )
    }

    public mutating func record(
        learningTokens: [NextInputLearningToken],
        source: NextInputLearningSource = .directInput
    ) {
        let normalized = learningTokens.compactMap { token -> NextInputLearningToken? in
            guard let text = Self.normalizedValue(token.text) else {
                return nil
            }
            return NextInputLearningToken(
                text: text,
                reading: Self.normalizedReading(token.reading)
            )
        }
        guard !normalized.isEmpty,
              normalized.count == learningTokens.count else {
            breakSequence()
            return
        }
        switch source {
        case .directInput:
            episode = nil
        case .acceptedSuggestion:
            extendEpisode(with: normalized)
        }
        for (index, token) in normalized.enumerated() {
            // A combined suggestion is used as a whole, so its first token
            // alone was not chosen after the preceding context
            recordSentenceToken(
                token.text,
                reading: token.reading,
                source: source,
                refreshesRecency: index > 0 || normalized.count == 1
            )
        }
        if source == .acceptedSuggestion {
            recordEpisodeEvidence()
        }
    }

    private mutating func recordSentenceToken(
        _ normalized: String,
        reading: String?,
        source: NextInputLearningSource,
        refreshesRecency: Bool
    ) {
        sequence += 1
        if let previous = lastInput, previous != normalized {
            var context = contexts[previous]
                ?? Context(candidates: [:], lastUsed: sequence)
            var stat = context.candidates[normalized]
                ?? CandidateStat(count: 0, lastUsed: 0)
            stat.count = min(stat.count + 1, Int.max - 1)
            if refreshesRecency {
                stat.lastUsed = sequence
            }
            context.candidates[normalized] = stat
            context.candidates = Self.compactedCandidates(
                context.candidates,
                limit: Self.maximumFollowersPerContext
            )
            context.lastUsed = sequence
            contexts[previous] = context
        }

        recordVariableLengthSequences(
            endingWith: normalized,
            reading: reading,
            source: source,
            refreshesRecency: refreshesRecency
        )
        recentInputs.append(normalized)
        recentReadings.append(reading)
        recentSources.append(source)
        let retained = Self.maximumContextTokenCount
            + Self.maximumPredictionTokenCount
        recentInputs = Array(recentInputs.suffix(retained))
        recentReadings = Array(recentReadings.suffix(retained))
        recentSources = Array(recentSources.suffix(retained))
        lastInput = normalized
        compactIfNeeded()
    }

    private mutating func extendEpisode(
        with learningTokens: [NextInputLearningToken]
    ) {
        let tokens = learningTokens.map(\.text)
        let readings = learningTokens.map(\.reading)
        if var current = episode,
           current.tokens.count + tokens.count
            <= Self.maximumPredictionTokenCount {
            current.tokens += tokens
            current.readings += readings
            current.selectionCount += 1
            episode = current
            return
        }
        let context = Array(recentInputs.suffix(Self.maximumContextTokenCount))
        let contextReadings = Array(
            recentReadings.suffix(Self.maximumContextTokenCount)
        )
        episode = context.isEmpty || tokens.count
            > Self.maximumPredictionTokenCount
            ? nil
            : SuggestionEpisode(
                context: context,
                contextReadings: contextReadings,
                tokens: tokens,
                readings: readings,
                selectionCount: 1
            )
    }

    /// Counts an episode the user built from several selections; picking an
    /// already combined suggestion only refreshes its recency
    private mutating func recordEpisodeEvidence() {
        guard let episode else { return }
        recordAcceptedPhraseEvidence(for: episode)
        guard episode.tokens.count >= 2,
              episode.tokens.joined().count <= Self.maximumValueLength else {
            return
        }
        let candidateKey = Self.key(for: episode.tokens)
        let counts = episode.selectionCount >= 2
        for contextLength in 1...episode.context.count {
            let contextKey = Self.key(for: Array(
                episode.context.suffix(contextLength)
            ))
            var context = sequenceContexts[contextKey]
                ?? SequenceContext(
                    candidates: [:], occurrenceCount: 0,
                    lastUsed: sequence
                )
            guard counts || context.candidates[candidateKey] != nil else {
                continue
            }
            var stat = context.candidates[candidateKey]
                ?? SequenceCandidateStat(
                    tokens: episode.tokens,
                    readings: episode.readings,
                    directCount: 0,
                    acceptedSuggestionCount: 0,
                    lastUsed: sequence
                )
            if Self.hasCompleteReadings(episode.readings) {
                stat.readings = episode.readings
            }
            if counts {
                stat.acceptedSuggestionCount = min(
                    stat.acceptedSuggestionCount + 1,
                    Int.max - 1
                )
                // Deleting a candidate also resets its counts, so building it
                // again twice afterwards is a new request for it
                if stat.acceptedSuggestionCount
                    >= Self.minimumEpisodePromotionCount {
                    suppressedCandidates.removeAll {
                        $0 == episode.tokens.joined()
                    }
                }
            }
            stat.lastUsed = sequence
            context.candidates[candidateKey] = stat
            context.candidates = Self.compactedSequenceCandidates(
                context.candidates,
                limit: Self.maximumFollowersPerContext
            )
            context.lastUsed = sequence
            sequenceContexts[contextKey] = context
        }
    }

    public func predictions(after value: String, limit: Int = 7)
        -> [NextInputPrediction] {
        guard let normalized = Self.normalizedValue(value) else { return [] }
        return predictions(after: [normalized], limit: limit)
    }

    public func predictions(after contextTokens: [String], limit: Int = 7)
        -> [NextInputPrediction] {
        let normalizedContext = contextTokens.compactMap(Self.normalizedValue)
        guard limit > 0, normalizedContext.count == contextTokens.count,
              !normalizedContext.isEmpty else {
            return []
        }

        let suppressed = Set(suppressedCandidates)
        var rankedByText: [String: RankedPrediction] = [:]

        if let immediate = normalizedContext.last,
           let context = contexts[immediate] {
            for (text, stat) in context.candidates
            where !suppressed.contains(text) {
                rankedByText[text] = RankedPrediction(
                    prediction: NextInputPrediction(
                        text: text,
                        sourceTokens: [text],
                        sourceReadings: []
                    ),
                    lastUsed: stat.lastUsed,
                    contextLength: 1
                )
            }
        }

        let maximumContextLength = min(
            Self.maximumContextTokenCount,
            normalizedContext.count
        )
        for contextLength in 1...maximumContextLength {
            let context = Array(normalizedContext.suffix(contextLength))
            guard let stored = sequenceContexts[Self.key(for: context)] else {
                continue
            }
            for stat in stored.candidates.values {
                let text = stat.tokens.joined()
                guard !suppressed.contains(text),
                      text.count <= Self.maximumValueLength,
                      Self.isEligible(stat)
                else {
                    continue
                }
                let ranked = RankedPrediction(
                    prediction: NextInputPrediction(
                        text: text,
                        sourceTokens: stat.tokens,
                        sourceReadings: stat.readings ?? []
                    ),
                    lastUsed: stat.lastUsed,
                    contextLength: contextLength
                )
                // Every matching context is a suffix of the current one, so
                // the candidate keeps its most recent use among them
                if let current = rankedByText[text],
                   !Self.shouldRank(ranked, before: current) {
                    continue
                }
                rankedByText[text] = ranked
            }
        }

        return rankedByText.values.sorted(by: Self.shouldRank)
            .prefix(limit)
            .map(\.prediction)
    }

    public func candidates(after value: String, limit: Int = 7) -> [String] {
        predictions(after: value, limit: limit).map(\.text)
    }

    public func candidates(after contextTokens: [String], limit: Int = 7)
        -> [String] {
        predictions(after: contextTokens, limit: limit).map(\.text)
    }

    public func learnedCompoundPredictions(
        matchingPrefix input: String,
        excluding visibleCandidates: Set<String> = [],
        limit: Int = maximumLearnedCompoundCandidateCount
    ) -> [LearnedCompoundPrediction] {
        let prefix = Self.normalizedReading(input) ?? ""
        guard limit > 0,
              prefix.count >= Self.minimumLearnedCompoundPrefixLength else {
            return []
        }
        let suppressed = Set(suppressedCandidates)
        let indexedKeys = learnedPhrasePrefixIndex[prefix] ?? []
        return indexedKeys.compactMap { learnedPhrases[$0] }.filter { stat in
            let text = stat.tokens.joined()
            return Self.isEligible(stat)
                && stat.tokens.count >= 2
                && Self.hasCompleteReadings(stat.readings)
                && stat.readings.compactMap { $0 }.joined().hasPrefix(prefix)
                && !visibleCandidates.contains(text)
                && !suppressed.contains(text)
        }.sorted { lhs, rhs in
            let lhsEvidence = lhs.directCount
                * Self.minimumEpisodePromotionCount
                + lhs.acceptedSuggestionCount
                    * Self.minimumDirectSequenceCount
            let rhsEvidence = rhs.directCount
                * Self.minimumEpisodePromotionCount
                + rhs.acceptedSuggestionCount
                    * Self.minimumDirectSequenceCount
            if lhs.lastUsed != rhs.lastUsed {
                return lhs.lastUsed > rhs.lastUsed
            }
            if lhsEvidence != rhsEvidence {
                return lhsEvidence > rhsEvidence
            }
            return lhs.tokens.joined() < rhs.tokens.joined()
        }.prefix(limit).map { stat in
            LearnedCompoundPrediction(
                text: stat.tokens.joined(),
                reading: stat.readings.compactMap { $0 }.joined(),
                sourceTokens: stat.tokens,
                sourceReadings: stat.readings
            )
        }
    }

    public mutating func suppress(_ candidate: String, after value: String) {
        guard Self.normalizedValue(value) != nil,
              let candidate = Self.normalizedValue(candidate) else { return }
        for context in contexts.keys {
            contexts[context]?.candidates.removeValue(forKey: candidate)
        }
        removeSequenceCandidates(matching: candidate)
        suppressedCandidates.removeAll { $0 == candidate }
        suppressedCandidates.insert(candidate, at: 0)
        suppressedCandidates = Array(
            suppressedCandidates.prefix(Self.maximumSuppressedCandidateCount)
        )
    }

    public mutating func forgetLearnedCandidate(_ candidate: String) {
        guard let candidate = Self.normalizedValue(candidate) else { return }
        for context in contexts.keys {
            contexts[context]?.candidates.removeValue(forKey: candidate)
        }
        removeSequenceCandidates(matching: candidate)
    }

    public func isSuppressed(_ candidate: String, after value: String) -> Bool {
        guard Self.normalizedValue(value) != nil,
              let candidate = Self.normalizedValue(candidate) else {
            return false
        }
        return suppressedCandidates.contains(candidate)
    }

    /// Records with `cursor` as the typing context instead of the model's own
    public mutating func record(
        tokens: [String],
        source: NextInputLearningSource = .directInput,
        cursor: inout NextInputSequenceCursor
    ) {
        let ownCursor = sequenceCursor
        sequenceCursor = cursor
        record(tokens: tokens, source: source)
        cursor = sequenceCursor
        sequenceCursor = ownCursor
    }

    public mutating func record(
        learningTokens: [NextInputLearningToken],
        source: NextInputLearningSource = .directInput,
        cursor: inout NextInputSequenceCursor
    ) {
        let ownCursor = sequenceCursor
        sequenceCursor = cursor
        record(learningTokens: learningTokens, source: source)
        cursor = sequenceCursor
        sequenceCursor = ownCursor
    }

    public func predictions(
        after cursor: NextInputSequenceCursor,
        limit: Int = 7
    ) -> [NextInputPrediction] {
        guard !cursor.recentInputs.isEmpty else { return [] }
        return predictions(after: cursor.recentInputs, limit: limit)
    }

    private var sequenceCursor: NextInputSequenceCursor {
        get {
            var cursor = NextInputSequenceCursor()
            cursor.recentInputs = recentInputs
            cursor.recentReadings = recentReadings
            cursor.recentSources = recentSources
            cursor.episode = episode
            cursor.lastInput = lastInput
            return cursor
        }
        set {
            recentInputs = newValue.recentInputs
            recentReadings = newValue.recentReadings
            recentSources = newValue.recentSources
            episode = newValue.episode
            lastInput = newValue.lastInput
        }
    }

    public func predictionsAfterLastInput(limit: Int = 7)
        -> [NextInputPrediction] {
        guard !recentInputs.isEmpty else { return [] }
        return predictions(after: recentInputs, limit: limit)
    }

    public func candidatesAfterLastInput(limit: Int = 7) -> [String] {
        predictionsAfterLastInput(limit: limit).map(\.text)
    }

    public mutating func removeAll() {
        contexts = [:]
        sequenceContexts = [:]
        learnedPhrases = [:]
        learnedPhrasePrefixIndex = [:]
        suppressedCandidates = []
        recentInputs = []
        recentReadings = []
        recentSources = []
        episode = nil
        sequence = 0
        lastInput = nil
    }

    public mutating func breakSequence() {
        recentInputs = []
        recentReadings = []
        recentSources = []
        episode = nil
        lastInput = nil
    }

    public var contextCount: Int {
        contexts.count
    }

    public var sequenceContextCount: Int {
        sequenceContexts.count
    }

    public var followerCount: Int {
        contexts.values.reduce(0) { $0 + $1.candidates.count }
            + sequenceContexts.values.reduce(0) { $0 + $1.candidates.count }
    }

    private mutating func recordVariableLengthSequences(
        endingWith value: String,
        reading: String?,
        source: NextInputLearningSource,
        refreshesRecency: Bool
    ) {
        let window = recentInputs + [value]
        let readingWindow = recentReadings + [reading]
        let windowSources = recentSources + [source]
        guard window.count >= 2 else { return }
        let immediatePredictionStart = window.count - 1
        let observedContextLength = min(
            Self.maximumContextTokenCount,
            immediatePredictionStart
        )
        for contextLength in 1...observedContextLength {
            let contextStart = immediatePredictionStart - contextLength
            let contextTokens = Array(
                window[contextStart..<immediatePredictionStart]
            )
            let contextKey = Self.key(for: contextTokens)
            var context = sequenceContexts[contextKey]
                ?? SequenceContext(
                    candidates: [:], occurrenceCount: 0,
                    lastUsed: sequence
                )
            context.occurrenceCount = min(
                context.occurrenceCount + 1,
                Int.max - 1
            )
            context.lastUsed = sequence
            sequenceContexts[contextKey] = context
        }
        let maximumPredictionLength = min(
            Self.maximumPredictionTokenCount,
            window.count - 1
        )
        for predictionLength in 1...maximumPredictionLength {
            let predictionStart = window.count - predictionLength
            let tokens = Array(window[predictionStart...])
            guard tokens.joined().count <= Self.maximumValueLength else {
                continue
            }
            // Multi-token sentence evidence needs every token typed directly;
            // accepted runs are learned as episodes instead
            if predictionLength >= 2,
               windowSources[predictionStart...].contains(where: {
                   $0 != .directInput
               }) {
                continue
            }
            let maximumContextLength = min(
                Self.maximumContextTokenCount,
                predictionStart
            )
            guard maximumContextLength > 0 else { continue }
            for contextLength in 1...maximumContextLength {
                if contextLength == 1, predictionLength == 1 { continue }
                let contextTokens = Array(
                    window[(predictionStart - contextLength)..<predictionStart]
                )
                let contextKey = Self.key(for: contextTokens)
                var context = sequenceContexts[contextKey]
                    ?? SequenceContext(
                        candidates: [:], occurrenceCount: 0,
                        lastUsed: sequence
                    )
                let candidateKey = Self.key(for: tokens)
                var stat = context.candidates[candidateKey]
                    ?? SequenceCandidateStat(
                        tokens: tokens,
                        readings: Array(readingWindow[predictionStart...]),
                        directCount: 0,
                        acceptedSuggestionCount: 0,
                        lastUsed: 0
                    )
                let readings = Array(readingWindow[predictionStart...])
                if Self.hasCompleteReadings(readings) {
                    stat.readings = readings
                }
                switch source {
                case .directInput:
                    stat.directCount = min(stat.directCount + 1, Int.max - 1)
                case .acceptedSuggestion:
                    stat.acceptedSuggestionCount = min(
                        stat.acceptedSuggestionCount + 1,
                        Int.max - 1
                    )
                }
                if refreshesRecency {
                    stat.lastUsed = sequence
                }
                context.candidates[candidateKey] = stat
                context.candidates = Self.compactedSequenceCandidates(
                    context.candidates,
                    limit: Self.maximumFollowersPerContext
                )
                context.lastUsed = sequence
                sequenceContexts[contextKey] = context
            }
        }
        if source == .directInput {
            recordDirectPhrases(
                window: window,
                readings: readingWindow,
                sources: windowSources
            )
        }
    }

    private mutating func recordDirectPhrases(
        window: [String],
        readings: [String?],
        sources: [NextInputLearningSource]
    ) {
        let maximumLength = min(
            Self.maximumPredictionTokenCount,
            window.count
        )
        guard maximumLength >= 2 else { return }
        for length in 2...maximumLength {
            let start = window.count - length
            let phraseTokens = Array(window[start...])
            let phraseReadings = Array(readings[start...])
            guard sources[start...].allSatisfy({ $0 == .directInput }),
                  phraseTokens.joined().count <= Self.maximumValueLength,
                  Self.hasCompleteReadings(phraseReadings) else {
                continue
            }
            updateLearnedPhrase(
                tokens: phraseTokens,
                readings: phraseReadings,
                incrementsDirectCount: true,
                incrementsAcceptedCount: false
            )
        }
    }

    private mutating func recordAcceptedPhraseEvidence(
        for episode: SuggestionEpisode
    ) {
        let selectionWasAlreadyCombined = episode.selectionCount == 1
            && episode.tokens.count >= 2
        if selectionWasAlreadyCombined {
            refreshLearnedPhraseIfPresent(
                tokens: episode.tokens,
                readings: episode.readings
            )
            return
        }
        guard let context = episode.context.last else { return }
        let contextReading = episode.contextReadings.last ?? nil
        let tokens = [context] + episode.tokens
        let readings = [contextReading] + episode.readings
        guard tokens.count <= Self.maximumPredictionTokenCount,
              tokens.joined().count <= Self.maximumValueLength,
              Self.hasCompleteReadings(readings) else {
            return
        }
        updateLearnedPhrase(
            tokens: tokens,
            readings: readings,
            incrementsDirectCount: false,
            incrementsAcceptedCount: true
        )
    }

    private mutating func updateLearnedPhrase(
        tokens: [String],
        readings: [String?],
        incrementsDirectCount: Bool,
        incrementsAcceptedCount: Bool
    ) {
        let key = Self.key(for: tokens)
        let previousPrefixes = learnedPhrases[key].map {
            Self.learnedPhrasePrefixes(for: $0.readings)
        } ?? []
        var stat = learnedPhrases[key] ?? LearnedPhraseStat(
            tokens: tokens,
            readings: readings,
            directCount: 0,
            acceptedSuggestionCount: 0,
            lastUsed: sequence
        )
        stat.readings = readings
        if incrementsDirectCount {
            stat.directCount = min(stat.directCount + 1, Int.max - 1)
        }
        if incrementsAcceptedCount {
            stat.acceptedSuggestionCount = min(
                stat.acceptedSuggestionCount + 1,
                Int.max - 1
            )
        }
        stat.lastUsed = sequence
        learnedPhrases[key] = stat
        let currentPrefixes = Self.learnedPhrasePrefixes(for: readings)
        for prefix in Set(previousPrefixes).subtracting(currentPrefixes) {
            learnedPhrasePrefixIndex[prefix]?.remove(key)
        }
        for prefix in currentPrefixes {
            learnedPhrasePrefixIndex[prefix, default: []].insert(key)
        }
        if Self.isEligible(stat) {
            suppressedCandidates.removeAll { $0 == tokens.joined() }
        }
    }

    private mutating func refreshLearnedPhraseIfPresent(
        tokens: [String],
        readings: [String?]
    ) {
        let key = Self.key(for: tokens)
        guard var stat = learnedPhrases[key] else { return }
        let previousPrefixes = Self.learnedPhrasePrefixes(for: stat.readings)
        if Self.hasCompleteReadings(readings) {
            stat.readings = readings
        }
        stat.lastUsed = sequence
        learnedPhrases[key] = stat
        let currentPrefixes = Self.learnedPhrasePrefixes(for: stat.readings)
        for prefix in Set(previousPrefixes).subtracting(currentPrefixes) {
            learnedPhrasePrefixIndex[prefix]?.remove(key)
        }
        for prefix in currentPrefixes {
            learnedPhrasePrefixIndex[prefix, default: []].insert(key)
        }
    }

    /// Candidates are ordered by their last use alone; context length only
    /// breaks ties
    private static func shouldRank(
        _ lhs: RankedPrediction,
        before rhs: RankedPrediction
    ) -> Bool {
        if lhs.lastUsed != rhs.lastUsed { return lhs.lastUsed > rhs.lastUsed }
        if lhs.contextLength != rhs.contextLength {
            return lhs.contextLength > rhs.contextLength
        }
        return lhs.prediction.text < rhs.prediction.text
    }

    /// A multi-token candidate is offered once it was typed as a sentence
    /// often enough or selected as the same run of suggestions twice
    private static func isEligible(_ stat: SequenceCandidateStat) -> Bool {
        stat.tokens.count == 1
            || stat.directCount >= minimumDirectSequenceCount
            || stat.acceptedSuggestionCount >= minimumEpisodePromotionCount
    }

    private static func isEligible(_ stat: LearnedPhraseStat) -> Bool {
        stat.directCount >= minimumDirectSequenceCount
            || stat.acceptedSuggestionCount >= minimumEpisodePromotionCount
    }

    private static func hasCompleteReadings(_ readings: [String?]) -> Bool {
        !readings.isEmpty && readings.allSatisfy { reading in
            guard let reading else { return false }
            return !reading.isEmpty
        }
    }

    private mutating func removeSequenceCandidates(matching text: String) {
        for key in Array(sequenceContexts.keys) {
            guard var context = sequenceContexts[key] else { continue }
            context.candidates = context.candidates.filter {
                $0.value.tokens.joined() != text
            }
            if context.candidates.isEmpty {
                sequenceContexts.removeValue(forKey: key)
            } else {
                sequenceContexts[key] = context
            }
        }
        learnedPhrases = learnedPhrases.filter {
            $0.value.tokens.joined() != text
        }
        rebuildLearnedPhrasePrefixIndex()
    }

    private mutating func compactIfNeeded() {
        if contexts.count > Self.maximumContextCount {
            contexts = Self.compactedContexts(contexts)
        }
        if sequenceContexts.count > Self.maximumContextCount {
            let retained = sequenceContexts.sorted {
                if $0.value.lastUsed != $1.value.lastUsed {
                    return $0.value.lastUsed > $1.value.lastUsed
                }
                return $0.key < $1.key
            }.prefix(Self.maximumContextCount)
            sequenceContexts = Dictionary(uniqueKeysWithValues: retained.map {
                ($0.key, $0.value)
            })
        }
        if learnedPhrases.count > Self.maximumContextCount {
            let retained = learnedPhrases.sorted {
                if $0.value.lastUsed != $1.value.lastUsed {
                    return $0.value.lastUsed > $1.value.lastUsed
                }
                return $0.key < $1.key
            }.prefix(Self.maximumContextCount)
            learnedPhrases = Dictionary(uniqueKeysWithValues: retained.map {
                ($0.key, $0.value)
            })
            rebuildLearnedPhrasePrefixIndex()
        }
    }

    private static func compactedContexts(
        _ contexts: [String: Context]
    ) -> [String: Context] {
        let retained = contexts.sorted {
            if $0.value.lastUsed != $1.value.lastUsed {
                return $0.value.lastUsed > $1.value.lastUsed
            }
            return $0.key < $1.key
        }.prefix(Self.maximumContextCount)
        return Dictionary(uniqueKeysWithValues: retained.map {
            ($0.key, $0.value)
        })
    }

    private static func compactedCandidates(
        _ candidates: [String: CandidateStat],
        limit: Int
    ) -> [String: CandidateStat] {
        guard candidates.count > limit else { return candidates }
        let retained = candidates.sorted {
            if $0.value.lastUsed != $1.value.lastUsed {
                return $0.value.lastUsed > $1.value.lastUsed
            }
            return $0.key < $1.key
        }.prefix(limit)
        return Dictionary(uniqueKeysWithValues: retained.map {
            ($0.key, $0.value)
        })
    }

    private static func compactedSequenceCandidates(
        _ candidates: [String: SequenceCandidateStat],
        limit: Int
    ) -> [String: SequenceCandidateStat] {
        guard candidates.count > limit else { return candidates }
        let retained = candidates.sorted {
            if $0.value.lastUsed != $1.value.lastUsed {
                return $0.value.lastUsed > $1.value.lastUsed
            }
            return $0.key < $1.key
        }.prefix(limit)
        return Dictionary(uniqueKeysWithValues: retained.map {
            ($0.key, $0.value)
        })
    }

    private static func droppingMultiTokenCandidates(
        _ contexts: [String: SequenceContext]
    ) -> [String: SequenceContext] {
        var result: [String: SequenceContext] = [:]
        for (key, var context) in contexts {
            context.candidates = context.candidates.filter {
                $0.value.tokens.count == 1
            }
            if !context.candidates.isEmpty {
                result[key] = context
            }
        }
        return result
    }

    private static func key(for tokens: [String]) -> String {
        tokens.map { "\($0.utf8.count):\($0)" }.joined(separator: "|")
    }

    private static func learnedPhrasePrefixes(
        for readings: [String?]
    ) -> [String] {
        guard hasCompleteReadings(readings) else { return [] }
        let reading = readings.compactMap { $0 }.joined()
        guard reading.count >= minimumLearnedCompoundPrefixLength else {
            return []
        }
        return (minimumLearnedCompoundPrefixLength...reading.count).map {
            String(reading.prefix($0))
        }
    }

    private mutating func rebuildLearnedPhrasePrefixIndex() {
        learnedPhrasePrefixIndex = [:]
        for (key, stat) in learnedPhrases {
            for prefix in Self.learnedPhrasePrefixes(for: stat.readings) {
                learnedPhrasePrefixIndex[prefix, default: []].insert(key)
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case contexts
        case sequenceContexts
        case learnedPhrases
        case sequence
        case lastInput
        case recentInputs
        case recentReadings
        case recentSources
        case sequenceVersion
        case suppressedCandidates
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(contexts, forKey: .contexts)
        try container.encode(sequenceContexts, forKey: .sequenceContexts)
        try container.encode(learnedPhrases, forKey: .learnedPhrases)
        try container.encode(sequence, forKey: .sequence)
        try container.encodeIfPresent(lastInput, forKey: .lastInput)
        try container.encode(recentInputs, forKey: .recentInputs)
        try container.encode(recentReadings, forKey: .recentReadings)
        try container.encode(recentSources, forKey: .recentSources)
        try container.encode(Self.sequenceSchemaVersion, forKey: .sequenceVersion)
        try container.encode(suppressedCandidates, forKey: .suppressedCandidates)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        contexts = try container.decodeIfPresent(
            [String: Context].self,
            forKey: .contexts
        ) ?? [:]
        sequenceContexts = try container.decodeIfPresent(
            [String: SequenceContext].self,
            forKey: .sequenceContexts
        ) ?? [:]
        learnedPhrases = try container.decodeIfPresent(
            [String: LearnedPhraseStat].self,
            forKey: .learnedPhrases
        ) ?? [:]
        learnedPhrasePrefixIndex = [:]
        sequence = try container.decodeIfPresent(Int.self, forKey: .sequence)
            ?? 0
        lastInput = try container.decodeIfPresent(
            String.self,
            forKey: .lastInput
        )
        recentInputs = try container.decodeIfPresent(
            [String].self,
            forKey: .recentInputs
        ) ?? lastInput.map { [$0] } ?? []
        recentReadings = try container.decodeIfPresent(
            [String?].self,
            forKey: .recentReadings
        ) ?? Array(repeating: nil, count: recentInputs.count)
        if let global = try? container.decode(
            [String].self,
            forKey: .suppressedCandidates
        ) {
            suppressedCandidates = global
        } else {
            let contextual = try container.decodeIfPresent(
                [String: [String]].self,
                forKey: .suppressedCandidates
            ) ?? [:]
            var seen = Set<String>()
            suppressedCandidates = contextual.values
                .flatMap { $0 }
                .filter { seen.insert($0).inserted }
        }
        suppressedCandidates = Array(
            suppressedCandidates.prefix(Self.maximumSuppressedCandidateCount)
        )
        for key in Array(contexts.keys) {
            guard var context = contexts[key] else { continue }
            context.candidates = Self.compactedCandidates(
                context.candidates,
                limit: Self.maximumFollowersPerContext
            )
            contexts[key] = context
        }
        for key in Array(sequenceContexts.keys) {
            guard var context = sequenceContexts[key] else { continue }
            context.candidates = Self.compactedSequenceCandidates(
                context.candidates,
                limit: Self.maximumFollowersPerContext
            )
            sequenceContexts[key] = context
        }
        let storedVersion = try container.decodeIfPresent(
            Int.self,
            forKey: .sequenceVersion
        ) ?? 1
        if storedVersion < Self.sequenceSchemaVersion {
            sequenceContexts = Self.droppingMultiTokenCandidates(
                sequenceContexts
            )
        }
        compactIfNeeded()
        rebuildLearnedPhrasePrefixIndex()
        let storedSources = try container.decodeIfPresent(
            [NextInputLearningSource].self,
            forKey: .recentSources
        ) ?? []
        var restoredInputs: [String] = []
        var restoredReadings: [String?] = []
        var restoredSources: [NextInputLearningSource] = []
        let sourceOffset = recentInputs.count - storedSources.count
        for (index, value) in recentInputs.enumerated() {
            guard let normalized = Self.normalizedValue(value) else { continue }
            restoredInputs.append(normalized)
            restoredReadings.append(
                recentReadings.indices.contains(index)
                    ? Self.normalizedReading(recentReadings[index])
                    : nil
            )
            let sourceIndex = index - sourceOffset
            restoredSources.append(
                storedSources.indices.contains(sourceIndex)
                    ? storedSources[sourceIndex]
                    : .directInput
            )
        }
        let retained = Self.maximumContextTokenCount
            + Self.maximumPredictionTokenCount
        recentInputs = Array(restoredInputs.suffix(retained))
        recentReadings = Array(restoredReadings.suffix(retained))
        recentSources = Array(restoredSources.suffix(retained))
        if let lastInput, Self.normalizedValue(lastInput) == nil {
            self.lastInput = nil
        }
    }

    private static func normalizedValue(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard
            !normalized.isEmpty,
            !normalized.contains("\n"),
            normalized.count <= maximumValueLength
        else {
            return nil
        }
        return normalized
    }

    private static func normalizedReading(_ reading: String?) -> String? {
        guard let reading else { return nil }
        let normalized = reading.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !normalized.isEmpty,
              !normalized.contains("\n"),
              normalized.count <= maximumValueLength else {
            return nil
        }
        return RomajiCanonicalizer.canonicalInput(from: normalized)
    }
}

public enum NextInputCandidateMerger {
    public static func merged(
        preferred: [String],
        learned: [String],
        limit: Int
    ) -> [String] {
        guard limit > 0 else { return [] }
        var seen = Set<String>()
        return (preferred + learned).filter {
            seen.insert($0).inserted
        }.prefix(limit).map { $0 }
    }

    public static func merged(
        preferred: [Candidate],
        learned: [Candidate],
        limit: Int
    ) -> [Candidate] {
        guard limit > 0 else { return [] }
        var seen = Set<String>()
        return (preferred + learned).filter {
            seen.insert($0.commitText).inserted
        }.prefix(limit).map { $0 }
    }
}
