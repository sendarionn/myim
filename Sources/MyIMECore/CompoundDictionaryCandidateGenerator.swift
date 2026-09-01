public struct CompoundDictionaryCandidateGenerator: Sendable {
    private struct Path: Sendable {
        let readings: [String]

        var shortSegmentCount: Int {
            readings.count { $0.count == 2 }
        }

        var minimumSegmentLength: Int {
            readings.map(\.count).min() ?? 0
        }

        var squaredLengthTotal: Int {
            readings.reduce(0) { $0 + $1.count * $1.count }
        }
    }

    private let candidatesByReading: [String: [String]]

    public init(entries: [DictionaryEntry]) {
        self.init(layers: [entries])
    }

    public init(layers: [[DictionaryEntry]]) {
        var candidatesByReading: [String: [String]] = [:]
        for layer in layers {
            for entry in layer {
                let reading = entry.input.lowercased()
                guard reading.count >= 2 else { continue }
                for candidate in entry.candidates
                where candidatesByReading[reading, default: []].contains(candidate) == false {
                    candidatesByReading[reading, default: []].append(candidate)
                }
            }
        }
        self.candidatesByReading = candidatesByReading
    }

    public func candidates(
        for input: String,
        limit: Int = 8,
        additionalCandidates: @Sendable (String) -> [String] = { _ in [] }
    ) -> [String] {
        let input = input.lowercased()
        let directCandidates = Set(mergedCandidates(
            for: input,
            additionalCandidates: additionalCandidates
        ))
        guard input.count >= 4,
              limit > 0,
              let path = bestPath(
                for: input,
                additionalCandidates: additionalCandidates
              ),
              path.readings.count >= 2 else {
            return []
        }

        var results: [(text: String, cost: Int)] = [("", 0)]
        for reading in path.readings {
            let segmentCandidates = mergedCandidates(
                for: reading,
                additionalCandidates: additionalCandidates
            )
            guard !segmentCandidates.isEmpty else {
                return []
            }
            var expanded: [(text: String, cost: Int)] = []
            for prefix in results {
                for (index, candidate) in segmentCandidates.enumerated() {
                    expanded.append((
                        prefix.text + candidate,
                        prefix.cost + index
                    ))
                }
            }
            results = Array(expanded.sorted {
                if $0.cost != $1.cost { return $0.cost < $1.cost }
                return $0.text < $1.text
            }.prefix(limit + directCandidates.count))
        }
        return results.map(\.text)
            .removingDuplicateStrings()
            .filter { !directCandidates.contains($0) }
            .prefix(limit)
            .map { $0 }
    }

    private func bestPath(
        for input: String,
        additionalCandidates: @Sendable (String) -> [String]
    ) -> Path? {
        let characters = Array(input)
        var paths = Array<Path?>(repeating: nil, count: characters.count + 1)
        paths[characters.count] = Path(readings: [])

        for start in stride(from: characters.count - 1, through: 0, by: -1) {
            let maximumEnd = characters.count
            guard start + 2 <= maximumEnd else { continue }
            for end in (start + 2)...maximumEnd {
                if start == 0, end == characters.count { continue }
                let reading = String(characters[start..<end])
                guard !mergedCandidates(
                    for: reading,
                    additionalCandidates: additionalCandidates
                ).isEmpty,
                      let suffix = paths[end] else { continue }
                let candidate = Path(readings: [reading] + suffix.readings)
                if paths[start].map({ isBetter(candidate, than: $0) }) ?? true {
                    paths[start] = candidate
                }
            }
        }
        return paths[0]
    }

    private func mergedCandidates(
        for reading: String,
        additionalCandidates: @Sendable (String) -> [String]
    ) -> [String] {
        ((candidatesByReading[reading] ?? []) + additionalCandidates(reading))
            .removingDuplicateStrings()
    }

    private func isBetter(_ lhs: Path, than rhs: Path) -> Bool {
        if lhs.readings.count != rhs.readings.count {
            return lhs.readings.count < rhs.readings.count
        }
        if lhs.shortSegmentCount != rhs.shortSegmentCount {
            return lhs.shortSegmentCount < rhs.shortSegmentCount
        }
        if lhs.minimumSegmentLength != rhs.minimumSegmentLength {
            return lhs.minimumSegmentLength > rhs.minimumSegmentLength
        }
        if lhs.squaredLengthTotal != rhs.squaredLengthTotal {
            return lhs.squaredLengthTotal > rhs.squaredLengthTotal
        }
        return lhs.readings.lexicographicallyPrecedes(rhs.readings)
    }
}

private extension Array where Element == String {
    func removingDuplicateStrings() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}
