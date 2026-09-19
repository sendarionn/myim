import Foundation

public struct DictionaryContinuationCandidateGenerator: Sendable {
    private let candidates: [String]

    public init(entries: [DictionaryEntry]) {
        var seen = Set<String>()
        candidates = entries.flatMap(\.candidates).compactMap { candidate in
            let value = CandidateCommitNormalizer.value(from: candidate)
            return !value.isEmpty && seen.insert(value).inserted ? value : nil
        }.sorted()
    }

    public func candidates(after committedValue: String, limit: Int = 8) -> [String] {
        guard committedValue.count >= 2, limit > 0 else { return [] }
        var index = lowerBound(of: committedValue)
        var seen = Set<String>()
        var result: [String] = []
        while candidates.indices.contains(index),
              candidates[index].hasPrefix(committedValue) {
            let candidate = candidates[index]
            let continuation = String(candidate.dropFirst(committedValue.count))
            if !continuation.isEmpty,
               continuation.count <= NextInputPredictionModel.maximumValueLength,
               seen.insert(continuation).inserted {
                result.append(continuation)
            }
            index += 1
        }
        return result.sorted {
            if $0.count != $1.count { return $0.count < $1.count }
            return $0 < $1
        }.prefix(limit).map { $0 }
    }

    private func lowerBound(of value: String) -> Int {
        var lower = 0
        var upper = candidates.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if candidates[middle] < value {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }
}
