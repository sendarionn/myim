import Foundation

struct SymmetricDeleteIndex: Sendable {
    private struct Row: Sendable {
        let hash: UInt64
        let identifier: Int
    }

    /// Sorted rows avoid the per-key Dictionary and Array allocations that
    /// dominate the typo index's resident memory.
    private let rows: [Row]
    let maximumDistance: Int

    init(terms: [String], maximumDistance: Int) {
        self.maximumDistance = max(0, maximumDistance)
        var rows: [Row] = []
        for (identifier, term) in terms.enumerated() {
            for key in Self.keys(
                for: term,
                maximumDistance: self.maximumDistance
            ) {
                rows.append(Row(
                    hash: Self.hash(key),
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

    func candidateIdentifiers(
        for term: String,
        maximumDistance: Int
    ) -> Set<Int> {
        let distance = min(max(0, maximumDistance), self.maximumDistance)
        var identifiers = Set<Int>()
        for key in Self.keys(for: term, maximumDistance: distance) {
            let hash = Self.hash(key)
            var index = lowerBound(for: hash)
            while index < rows.count, rows[index].hash == hash {
                identifiers.insert(rows[index].identifier)
                index += 1
            }
        }
        return identifiers
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

    static func keys(
        for term: String,
        maximumDistance: Int
    ) -> Set<String> {
        var result: Set<String> = [term]
        var frontier: Set<String> = [term]
        guard maximumDistance > 0 else {
            return result
        }
        for _ in 0..<maximumDistance {
            var next: Set<String> = []
            for value in frontier where !value.isEmpty {
                let characters = Array(value)
                for index in characters.indices {
                    var deleted = characters
                    deleted.remove(at: index)
                    let key = String(deleted)
                    if result.insert(key).inserted {
                        next.insert(key)
                    }
                }
            }
            frontier = next
            if frontier.isEmpty {
                break
            }
        }
        return result
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
