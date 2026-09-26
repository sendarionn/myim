import Foundation

public struct NextInputPredictionModel: Codable, Sendable {
    public static let maximumContextCount = 2_048
    public static let maximumFollowersPerContext = 16
    public static let maximumSuppressedCandidateCount = 1_024
    public static let maximumValueLength = 80

    private struct CandidateStat: Codable, Sendable {
        var count: Int
        var lastUsed: Int
    }

    private struct Context: Codable, Sendable {
        var candidates: [String: CandidateStat]
        var lastUsed: Int
    }

    private var contexts: [String: Context] = [:]
    private var suppressedCandidates: [String] = []
    private var sequence = 0
    public private(set) var lastInput: String?

    public init() {}

    public mutating func record(_ value: String) {
        guard let normalized = Self.normalizedValue(value) else {
            lastInput = nil
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
        lastInput = normalized
        compactIfNeeded()
    }

    public func candidates(after value: String, limit: Int = 7) -> [String] {
        guard
            limit > 0,
            let normalized = Self.normalizedValue(value),
            let context = contexts[normalized]
        else {
            return []
        }
        let suppressed = Set(suppressedCandidates)
        return context.candidates
            .filter { !suppressed.contains($0.key) }
            .sorted {
                if $0.value.lastUsed != $1.value.lastUsed {
                    return $0.value.lastUsed > $1.value.lastUsed
                }
                return $0.key < $1.key
            }
            .prefix(limit)
            .map(\.key)
    }

    public mutating func suppress(_ candidate: String, after value: String) {
        guard Self.normalizedValue(value) != nil,
              let candidate = Self.normalizedValue(candidate) else { return }
        for context in contexts.keys {
            contexts[context]?.candidates.removeValue(forKey: candidate)
        }
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
    }

    public func isSuppressed(_ candidate: String, after value: String) -> Bool {
        guard Self.normalizedValue(value) != nil,
              let candidate = Self.normalizedValue(candidate) else {
            return false
        }
        return suppressedCandidates.contains(candidate)
    }

    public func candidatesAfterLastInput(limit: Int = 7) -> [String] {
        guard let lastInput else {
            return []
        }
        return candidates(after: lastInput, limit: limit)
    }

    public mutating func removeAll() {
        contexts = [:]
        suppressedCandidates = []
        sequence = 0
        lastInput = nil
    }

    public mutating func breakSequence() {
        lastInput = nil
    }

    public var contextCount: Int {
        contexts.count
    }

    public var followerCount: Int {
        contexts.values.reduce(0) { $0 + $1.candidates.count }
    }

    private mutating func compactIfNeeded() {
        guard contexts.count > Self.maximumContextCount else { return }
        let retained = contexts.sorted {
            if $0.value.lastUsed != $1.value.lastUsed {
                return $0.value.lastUsed > $1.value.lastUsed
            }
            return $0.key < $1.key
        }.prefix(Self.maximumContextCount)
        contexts = Dictionary(uniqueKeysWithValues: retained.map {
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

    private enum CodingKeys: String, CodingKey {
        case contexts
        case sequence
        case lastInput
        case suppressedCandidates
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        contexts = try container.decodeIfPresent(
            [String: Context].self,
            forKey: .contexts
        ) ?? [:]
        sequence = try container.decodeIfPresent(Int.self, forKey: .sequence)
            ?? 0
        lastInput = try container.decodeIfPresent(
            String.self,
            forKey: .lastInput
        )
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
        if contexts.count > Self.maximumContextCount {
            let retained = contexts.sorted {
                if $0.value.lastUsed != $1.value.lastUsed {
                    return $0.value.lastUsed > $1.value.lastUsed
                }
                return $0.key < $1.key
            }.prefix(Self.maximumContextCount)
            contexts = Dictionary(uniqueKeysWithValues: retained.map {
                ($0.key, $0.value)
            })
        }
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
}
