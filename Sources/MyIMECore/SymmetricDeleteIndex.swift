import Foundation

struct SymmetricDeleteIndex: Sendable {
    private let valuesByDeleteHash: [UInt64: [Int]]
    let maximumDistance: Int

    init(terms: [String], maximumDistance: Int) {
        self.maximumDistance = max(0, maximumDistance)
        var index: [UInt64: [Int]] = [:]
        for (identifier, term) in terms.enumerated() {
            for key in Self.keys(
                for: term,
                maximumDistance: self.maximumDistance
            ) {
                index[Self.hash(key), default: []].append(identifier)
            }
        }
        valuesByDeleteHash = index
    }

    func candidateIdentifiers(
        for term: String,
        maximumDistance: Int
    ) -> Set<Int> {
        let distance = min(max(0, maximumDistance), self.maximumDistance)
        var identifiers = Set<Int>()
        for key in Self.keys(for: term, maximumDistance: distance) {
            identifiers.formUnion(valuesByDeleteHash[Self.hash(key)] ?? [])
        }
        return identifiers
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
