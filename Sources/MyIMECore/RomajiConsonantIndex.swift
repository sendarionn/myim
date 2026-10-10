import Foundation

/// A bounded second-stage retrieval index for long romaji typos
///
/// Vowels are deliberately removed before this index is used. Shared
/// consonant bigrams retain rough mora order while tolerating multiple missing
/// vowels without constructing a combinatorial high-distance delete index
struct RomajiConsonantIndex: Sendable {
    private struct Row: Sendable {
        let hash: UInt64
        let identifier: Int
    }

    private let rows: [Row]

    init(terms: [String]) {
        var rows: [Row] = []
        for (identifier, term) in terms.enumerated() {
            for ngram in Self.ngrams(in: term) {
                rows.append(Row(
                    hash: Self.hash(ngram),
                    identifier: identifier
                ))
            }
        }
        rows.sort {
            if $0.hash != $1.hash {
                return $0.hash < $1.hash
            }
            return $0.identifier < $1.identifier
        }
        self.rows = rows
    }

    func rankedCandidateIdentifiers(
        for term: String,
        minimumSharedNGramCount: Int,
        limit: Int
    ) -> [Int] {
        guard limit > 0 else { return [] }
        var sharedCounts: [Int: UInt8] = [:]
        for ngram in Self.ngrams(in: term) {
            let hash = Self.hash(ngram)
            var index = lowerBound(for: hash)
            while index < rows.count, rows[index].hash == hash {
                let identifier = rows[index].identifier
                sharedCounts[identifier, default: 0] &+= 1
                index += 1
            }
        }
        let minimum = max(1, minimumSharedNGramCount)
        return sharedCounts.lazy.filter {
            Int($0.value) >= minimum
        }.sorted {
            if $0.value != $1.value {
                return $0.value > $1.value
            }
            return $0.key < $1.key
        }.prefix(limit).map(\.key)
    }

    static func ngrams(in term: String) -> Set<String> {
        let characters = Array("^" + term + "$")
        guard characters.count >= 2 else { return [] }
        return Set((0..<(characters.count - 1)).map {
            String(characters[$0...($0 + 1)])
        })
    }

    private func lowerBound(for hash: UInt64) -> Int {
        var lower = 0
        var upper = rows.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if rows[middle].hash < hash {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }

    private static func hash(_ value: String) -> UInt64 {
        var result: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            result ^= UInt64(byte)
            result &*= 1_099_511_628_211
        }
        return result
    }
}
