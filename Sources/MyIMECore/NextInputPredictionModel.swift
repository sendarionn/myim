import Foundation

public struct NextInputPredictionModel: Codable, Sendable {
    public static let maximumContextCount = 256
    public static let maximumFollowersPerContext = 8
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
            context.lastUsed = sequence
            context.candidates = Self.prunedCandidates(context.candidates)
            contexts[previous] = context
            pruneContexts()
        }
        lastInput = normalized
    }

    public func candidates(after value: String, limit: Int = 7) -> [String] {
        guard
            limit > 0,
            let normalized = Self.normalizedValue(value),
            let context = contexts[normalized]
        else {
            return []
        }
        guard let mostRecent = context.candidates.max(by: {
            if $0.value.lastUsed != $1.value.lastUsed {
                return $0.value.lastUsed < $1.value.lastUsed
            }
            return $0.key > $1.key
        }) else {
            return []
        }
        let remaining = context.candidates
            .filter { $0.key != mostRecent.key }
            .sorted {
                if $0.value.count != $1.value.count {
                    return $0.value.count > $1.value.count
                }
                if $0.value.lastUsed != $1.value.lastUsed {
                    return $0.value.lastUsed > $1.value.lastUsed
                }
                return $0.key < $1.key
            }
        return ([mostRecent] + remaining)
            .prefix(limit)
            .map(\.key)
    }

    public func candidatesAfterLastInput(limit: Int = 7) -> [String] {
        guard let lastInput else {
            return []
        }
        return candidates(after: lastInput, limit: limit)
    }

    public mutating func removeAll() {
        contexts = [:]
        sequence = 0
        lastInput = nil
    }

    public mutating func breakSequence() {
        lastInput = nil
    }

    public var contextCount: Int {
        contexts.count
    }

    private mutating func pruneContexts() {
        guard contexts.count > Self.maximumContextCount else {
            return
        }
        let retainedKeys = Set(
            contexts.sorted {
                $0.value.lastUsed > $1.value.lastUsed
            }
            .prefix(Self.maximumContextCount)
            .map(\.key)
        )
        contexts = contexts.filter { retainedKeys.contains($0.key) }
    }

    private static func prunedCandidates(
        _ candidates: [String: CandidateStat]
    ) -> [String: CandidateStat] {
        guard candidates.count > maximumFollowersPerContext else {
            return candidates
        }
        guard let mostRecent = candidates.max(by: {
            if $0.value.lastUsed != $1.value.lastUsed {
                return $0.value.lastUsed < $1.value.lastUsed
            }
            return $0.key > $1.key
        }) else {
            return candidates
        }
        let retainedKeys = Set(
            [mostRecent.key] + candidates
                .filter { $0.key != mostRecent.key }
                .sorted {
                    if $0.value.count != $1.value.count {
                        return $0.value.count > $1.value.count
                    }
                    if $0.value.lastUsed != $1.value.lastUsed {
                        return $0.value.lastUsed > $1.value.lastUsed
                    }
                    return $0.key < $1.key
                }
                .prefix(maximumFollowersPerContext - 1)
                .map(\.key)
        )
        return candidates.filter { retainedKeys.contains($0.key) }
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
