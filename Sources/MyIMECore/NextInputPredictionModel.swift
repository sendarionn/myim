import Foundation

public enum NextInputLearningSource: String, Codable, Sendable {
    case directInput
    case acceptedSuggestion
}

public struct NextInputPrediction: Equatable, Sendable {
    public let text: String
    public let sourceTokens: [String]

    public init(text: String, sourceTokens: [String]) {
        self.text = text
        self.sourceTokens = sourceTokens
    }
}

public enum NextInputCandidateMetadata {
    public static let sourceTokensKey = "nextInput.sourceTokens"
    public static let acceptedSuggestionKey = "nextInput.acceptedSuggestion"

    public static func candidate(from prediction: NextInputPrediction) -> Candidate {
        Candidate(
            storageText: prediction.text,
            source: .nextInput,
            contextualMetadata: [
                sourceTokensKey: encodedTokens(prediction.sourceTokens),
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

    public static func isAcceptedSuggestion(_ candidate: Candidate) -> Bool {
        candidate.contextualMetadata[acceptedSuggestionKey] == "true"
    }

    private static func encodedTokens(_ tokens: [String]) -> String {
        (try? JSONEncoder().encode(tokens).base64EncodedString()) ?? ""
    }
}

public struct NextInputPredictionModel: Codable, Sendable {
    public static let maximumContextCount = 2_048
    public static let maximumFollowersPerContext = 16
    public static let maximumSuppressedCandidateCount = 1_024
    public static let maximumValueLength = 80
    public static let maximumContextTokenCount = 4
    public static let maximumPredictionTokenCount = 4
    public static let minimumDirectSequenceCount = 3

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
        var directCount: Int
        var acceptedSuggestionCount: Int
        var lastUsed: Int
    }

    private struct SequenceContext: Codable, Sendable {
        var candidates: [String: SequenceCandidateStat]
        var occurrenceCount: Int
        var lastUsed: Int
    }

    private struct RankedPrediction {
        let prediction: NextInputPrediction
        let score: Double
        let lastUsed: Int
        let contextLength: Int
    }

    // `contexts` keeps the existing one-token history schema readable
    private var contexts: [String: Context] = [:]
    private var sequenceContexts: [String: SequenceContext] = [:]
    private var suppressedCandidates: [String] = []
    private var recentInputs: [String] = []
    private var sequence = 0
    public private(set) var lastInput: String?

    public init() {}

    public mutating func record(
        _ value: String,
        source: NextInputLearningSource = .directInput
    ) {
        guard let normalized = Self.normalizedValue(value) else {
            breakSequence()
            return
        }

        sequence += 1
        if let previous = lastInput, previous != normalized {
            var context = contexts[previous]
                ?? Context(candidates: [:], lastUsed: sequence)
            var stat = context.candidates[normalized]
                ?? CandidateStat(count: 0, lastUsed: sequence)
            stat.count = min(stat.count + 1, Int.max - 1)
            stat.lastUsed = sequence
            context.candidates[normalized] = stat
            context.candidates = Self.compactedCandidates(
                context.candidates,
                limit: Self.maximumFollowersPerContext
            )
            context.lastUsed = sequence
            contexts[previous] = context
        }

        recordVariableLengthSequences(endingWith: normalized, source: source)
        recentInputs.append(normalized)
        recentInputs = Array(recentInputs.suffix(
            Self.maximumContextTokenCount + Self.maximumPredictionTokenCount
        ))
        lastInput = normalized
        compactIfNeeded()
    }

    public mutating func record(
        tokens: [String],
        source: NextInputLearningSource = .directInput
    ) {
        for token in tokens {
            record(token, source: source)
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
            let total = max(1, context.candidates.values.reduce(0) {
                $0 + $1.count
            })
            for (text, stat) in context.candidates
            where !suppressed.contains(text) {
                rankedByText[text] = rankedPrediction(
                    tokens: [text],
                    directCount: stat.count,
                    acceptedSuggestionCount: 0,
                    occurrenceCount: total,
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
                      stat.tokens.count == 1
                        || stat.directCount >= Self.minimumDirectSequenceCount
                else {
                    continue
                }
                let ranked = rankedPrediction(
                    tokens: stat.tokens,
                    directCount: stat.directCount,
                    acceptedSuggestionCount: stat.acceptedSuggestionCount,
                    occurrenceCount: stored.occurrenceCount,
                    lastUsed: stat.lastUsed,
                    contextLength: contextLength
                )
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
        suppressedCandidates = []
        recentInputs = []
        sequence = 0
        lastInput = nil
    }

    public mutating func breakSequence() {
        recentInputs = []
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
        source: NextInputLearningSource
    ) {
        let window = recentInputs + [value]
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
                        directCount: 0,
                        acceptedSuggestionCount: 0,
                        lastUsed: sequence
                    )
                switch source {
                case .directInput:
                    stat.directCount = min(stat.directCount + 1, Int.max - 1)
                case .acceptedSuggestion:
                    stat.acceptedSuggestionCount = min(
                        stat.acceptedSuggestionCount + 1,
                        Int.max - 1
                    )
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
    }

    private func rankedPrediction(
        tokens: [String],
        directCount: Int,
        acceptedSuggestionCount: Int,
        occurrenceCount: Int,
        lastUsed: Int,
        contextLength: Int
    ) -> RankedPrediction {
        let effectiveCount = Double(directCount)
            + Double(acceptedSuggestionCount) * 0.25
        let conditionalProbability = min(
            1,
            effectiveCount / Double(max(1, occurrenceCount))
        )
        let age = max(0, sequence - lastUsed)
        let recency = 8 / Double(age + 1)
        let score = Double(contextLength) * 50
            + log2(1 + effectiveCount) * 8
            + conditionalProbability * 20
            + recency
            + Double(max(0, tokens.count - 1)) * 2
        return RankedPrediction(
            prediction: NextInputPrediction(
                text: tokens.joined(),
                sourceTokens: tokens
            ),
            score: score,
            lastUsed: lastUsed,
            contextLength: contextLength
        )
    }

    private static func shouldRank(
        _ lhs: RankedPrediction,
        before rhs: RankedPrediction
    ) -> Bool {
        if lhs.contextLength == 1, rhs.contextLength == 1,
           lhs.prediction.sourceTokens.count == 1,
           rhs.prediction.sourceTokens.count == 1,
           lhs.lastUsed != rhs.lastUsed {
            return lhs.lastUsed > rhs.lastUsed
        }
        if lhs.score != rhs.score { return lhs.score > rhs.score }
        if lhs.contextLength != rhs.contextLength {
            return lhs.contextLength > rhs.contextLength
        }
        if lhs.lastUsed != rhs.lastUsed { return lhs.lastUsed > rhs.lastUsed }
        return lhs.prediction.text < rhs.prediction.text
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

    private static func key(for tokens: [String]) -> String {
        tokens.map { "\($0.utf8.count):\($0)" }.joined(separator: "|")
    }

    private enum CodingKeys: String, CodingKey {
        case contexts
        case sequenceContexts
        case sequence
        case lastInput
        case recentInputs
        case suppressedCandidates
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
        compactIfNeeded()
        recentInputs = recentInputs.compactMap(Self.normalizedValue)
        recentInputs = Array(recentInputs.suffix(
            Self.maximumContextTokenCount + Self.maximumPredictionTokenCount
        ))
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
