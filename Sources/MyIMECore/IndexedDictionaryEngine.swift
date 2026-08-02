import Foundation

public struct IndexedDictionaryEngine: @unchecked Sendable {
    private let data: Data
    private let readingOffsets: [Int]

    public init(contentsOf url: URL) throws {
        try self.init(data: Data(contentsOf: url, options: .mappedIfSafe))
    }

    public init(data: Data = Data()) {
        self.data = data
        readingOffsets = Self.makeReadingOffsets(in: data)
    }

    public var readingCount: Int {
        readingOffsets.count
    }

    public func candidates(for reading: String) -> [String] {
        guard !reading.isEmpty else {
            return []
        }
        let target = Array(reading.utf8)
        let index = lowerBound(of: target)
        guard
            readingOffsets.indices.contains(index),
            compareReading(at: index, with: target) == 0
        else {
            return []
        }
        return candidates(at: index, limit: .max)
    }

    public func candidates(
        matching prefix: String,
        limit: Int = .max
    ) -> [String] {
        guard !prefix.isEmpty, limit > 0 else {
            return []
        }
        let target = Array(prefix.utf8)
        var index = lowerBound(of: target)
        var seen = Set<String>()
        var result: [String] = []

        while readingOffsets.indices.contains(index),
              reading(at: index).starts(with: target) {
            for candidate in candidates(at: index, limit: limit - result.count)
            where seen.insert(candidate).inserted {
                result.append(candidate)
                if result.count == limit {
                    return result
                }
            }
            index += 1
        }
        return result
    }

    private static func makeReadingOffsets(in data: Data) -> [Int] {
        var offsets: [Int] = []
        var lineStart = 0
        while lineStart < data.count {
            var lineEnd = lineStart
            while lineEnd < data.count, data[lineEnd] != 0x0A {
                lineEnd += 1
            }
            if lineStart < lineEnd {
                let first = data[lineStart]
                if first != 0x20, first != 0x09, first != 0x0D {
                    offsets.append(lineStart)
                }
            }
            lineStart = lineEnd + 1
        }
        return offsets
    }

    private func lowerBound(of target: [UInt8]) -> Int {
        var lower = 0
        var upper = readingOffsets.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if compareReading(at: middle, with: target) < 0 {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }

    private func compareReading(at index: Int, with target: [UInt8]) -> Int {
        let value = reading(at: index)
        for position in 0..<min(value.count, target.count) {
            let valueIndex = value.index(
                value.startIndex,
                offsetBy: position
            )
            if value[valueIndex] != target[position] {
                return value[valueIndex] < target[position] ? -1 : 1
            }
        }
        if value.count == target.count {
            return 0
        }
        return value.count < target.count ? -1 : 1
    }

    private func reading(at index: Int) -> Data.SubSequence {
        let start = readingOffsets[index]
        var end = start
        while end < data.count, data[end] != 0x0A, data[end] != 0x0D {
            end += 1
        }
        return data[start..<end]
    }

    private func candidates(at index: Int, limit: Int) -> [String] {
        guard limit > 0 else {
            return []
        }
        var position = lineEnd(startingAt: readingOffsets[index])
        var seen = Set<String>()
        var result: [String] = []

        while position < data.count {
            let start = position
            let end = lineEnd(startingAt: start)
            position = end < data.count ? end + 1 : end
            guard start < end else {
                continue
            }
            let first = data[start]
            guard first == 0x20 || first == 0x09 else {
                break
            }
            var valueStart = start
            while valueStart < end,
                  data[valueStart] == 0x20 || data[valueStart] == 0x09 {
                valueStart += 1
            }
            var valueEnd = end
            while valueEnd > valueStart,
                  data[valueEnd - 1] == 0x0D || data[valueEnd - 1] == 0x20 {
                valueEnd -= 1
            }
            guard valueStart < valueEnd,
                  let value = String(
                    data: data[valueStart..<valueEnd],
                    encoding: .utf8
                  )
            else {
                continue
            }
            let normalized = CandidateCommitNormalizer.value(from: value)
            if !normalized.isEmpty, seen.insert(normalized).inserted {
                result.append(normalized)
                if result.count == limit {
                    return result
                }
            }
        }
        return result
    }

    private func lineEnd(startingAt start: Int) -> Int {
        var end = start
        while end < data.count, data[end] != 0x0A {
            end += 1
        }
        return end
    }
}
