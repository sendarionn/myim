import Foundation

public struct SortedConversionEngine: Sendable {
    private let candidatesByReading: [String: [String]]
    private let readings: [String]

    public init(entries: [DictionaryEntry]) {
        var values: [String: [String]] = [:]
        for entry in entries {
            for candidate in entry.candidates
            where values[entry.reading, default: []].contains(candidate) == false {
                values[entry.reading, default: []].append(candidate)
            }
        }
        candidatesByReading = values
        readings = values.keys.sorted()
    }

    public func candidates(for reading: String) -> [String] {
        candidatesByReading[reading] ?? []
    }

    public func candidates(matching prefix: String, limit: Int = .max) -> [String] {
        guard !prefix.isEmpty, limit > 0 else { return [] }
        var index = lowerBound(of: prefix)
        var seen = Set<String>()
        var result: [String] = []
        while index < readings.count, readings[index].hasPrefix(prefix) {
            for candidate in candidatesByReading[readings[index]] ?? []
            where seen.insert(candidate).inserted {
                result.append(candidate)
                if result.count == limit { return result }
            }
            index += 1
        }
        return result
    }

    private func lowerBound(of value: String) -> Int {
        var lower = 0
        var upper = readings.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if readings[middle] < value {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }
}
