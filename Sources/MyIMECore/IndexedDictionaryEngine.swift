import Foundation

public struct IndexedDictionaryEngine: @unchecked Sendable {
    private let data: Data
    private let readingOffsets: [Int]
    /// The dictionary never changes, so a prefix asked again, as when the
    /// same input is refreshed or typed again after a deletion, is answered
    /// from the last lookups; shared by copies of the engine
    private let recentGroups = GroupCache()

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
        return data.withUnsafeBytes { bytes in
            let index = lowerBound(of: target, in: bytes)
            guard
                readingOffsets.indices.contains(index),
                compare(readingRange(at: index, in: bytes), with: target, in: bytes) == 0
            else {
                return []
            }
            return candidates(at: index, limit: .max, in: bytes)
        }
    }

    public func candidates(
        matching prefix: String,
        limit: Int = .max
    ) -> [String] {
        candidateGroups(matching: prefix, limit: limit).all
    }

    public func readings(for candidate: String, limit: Int = 8) -> [String] {
        guard !candidate.isEmpty, limit > 0 else { return [] }
        let target = Data(candidate.utf8)
        var result: [String] = []
        for index in readingOffsets.indices {
            if containsCandidate(target, at: index),
               let reading = String(data: reading(at: index), encoding: .utf8) {
                result.append(reading)
                if result.count == limit { break }
            }
        }
        return result
    }

    public func readings(
        for candidates: [String],
        limitPerCandidate: Int = 8
    ) -> [String: [String]] {
        guard !candidates.isEmpty, limitPerCandidate > 0 else { return [:] }
        let targets = Set(candidates.filter { !$0.isEmpty })
        guard !targets.isEmpty else { return [:] }
        return data.withUnsafeBytes { bytes in
            var result: [String: [String]] = [:]
            for index in readingOffsets.indices {
                guard let reading = String(
                    bytes: UnsafeRawBufferPointer(
                        rebasing: bytes[readingRange(at: index, in: bytes)]
                    ),
                    encoding: .utf8
                ) else { continue }
                for candidate in self.candidates(at: index, limit: .max, in: bytes)
                where targets.contains(candidate) {
                    var readings = result[candidate] ?? []
                    if readings.count < limitPerCandidate,
                       !readings.contains(reading) {
                        readings.append(reading)
                        result[candidate] = readings
                    }
                }
                if result.count == targets.count,
                   result.values.allSatisfy({ $0.count >= limitPerCandidate }) {
                    break
                }
            }
            return result
        }
    }

    private func containsCandidate(_ target: Data, at index: Int) -> Bool {
        let expectedReading = reading(at: index)
        var position = readingOffsets[index]
        while position < data.count {
            let start = position
            let end = lineEnd(startingAt: start)
            position = end < data.count ? end + 1 : end
            guard start < end else { continue }
            guard let tab = data[start..<end].firstIndex(of: 0x09),
                  data[start..<tab].elementsEqual(expectedReading) else { break }
            let valueStart = tab + 1
            var valueEnd = end
            while valueEnd > valueStart,
                  data[valueEnd - 1] == 0x0D || data[valueEnd - 1] == 0x20 {
                valueEnd -= 1
            }
            if data[valueStart..<valueEnd].elementsEqual(target) {
                return true
            }
        }
        return false
    }

    public func candidateGroups(
        matching prefix: String,
        limit: Int = .max
    ) -> DictionaryCandidateGroups {
        guard !prefix.isEmpty, limit > 0 else {
            return DictionaryCandidateGroups()
        }
        let key = GroupCache.Key(prefix: prefix, limit: limit)
        if let cached = recentGroups.value(for: key) {
            return cached
        }
        let groups = lookUpGroups(matching: prefix, limit: limit)
        recentGroups.store(groups, for: key)
        return groups
    }

    private func lookUpGroups(
        matching prefix: String,
        limit: Int
    ) -> DictionaryCandidateGroups {
        let target = Array(prefix.utf8)
        return data.withUnsafeBytes { bytes in
            var index = lowerBound(of: target, in: bytes)
            var seen = Set<String>()
            var exact: [String] = []
            var prefixMatches: [String] = []

            while readingOffsets.indices.contains(index) {
                let reading = readingRange(at: index, in: bytes)
                guard Self.starts(reading, with: target, in: bytes) else { break }
                let isExactReading = reading.count == target.count
                for candidate in candidates(
                    at: index,
                    limit: limit - exact.count - prefixMatches.count,
                    in: bytes
                )
                where seen.insert(candidate).inserted {
                    if isExactReading {
                        exact.append(candidate)
                    } else {
                        prefixMatches.append(candidate)
                    }
                    if exact.count + prefixMatches.count == limit {
                        return DictionaryCandidateGroups(
                            exact: exact,
                            prefix: prefixMatches
                        )
                    }
                }
                index += 1
            }
            return DictionaryCandidateGroups(exact: exact, prefix: prefixMatches)
        }
    }

    private static func makeReadingOffsets(in data: Data) -> [Int] {
        var offsets: [Int] = []
        var lineStart = 0
        var previousReading = Data()
        while lineStart < data.count {
            var lineEnd = lineStart
            while lineEnd < data.count, data[lineEnd] != 0x0A {
                lineEnd += 1
            }
            if lineStart < lineEnd,
               let tab = data[lineStart..<lineEnd].firstIndex(of: 0x09) {
                let reading = Data(data[lineStart..<tab])
                if reading != previousReading {
                    offsets.append(lineStart)
                    previousReading = reading
                }
            }
            lineStart = lineEnd + 1
        }
        return offsets
    }

    // The lookups read the bytes directly; going through `Data` for each
    // byte costs more than the comparison itself

    private func lowerBound(
        of target: [UInt8],
        in bytes: UnsafeRawBufferPointer
    ) -> Int {
        var lower = 0
        var upper = readingOffsets.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if compare(readingRange(at: middle, in: bytes), with: target, in: bytes) < 0 {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }

    private func compare(
        _ range: Range<Int>,
        with target: [UInt8],
        in bytes: UnsafeRawBufferPointer
    ) -> Int {
        for position in 0..<min(range.count, target.count) {
            let value = bytes[range.lowerBound + position]
            if value != target[position] {
                return value < target[position] ? -1 : 1
            }
        }
        if range.count == target.count {
            return 0
        }
        return range.count < target.count ? -1 : 1
    }

    private static func starts(
        _ range: Range<Int>,
        with target: [UInt8],
        in bytes: UnsafeRawBufferPointer
    ) -> Bool {
        guard range.count >= target.count else { return false }
        for position in target.indices
        where bytes[range.lowerBound + position] != target[position] {
            return false
        }
        return true
    }

    private static func equal(
        _ lhs: Range<Int>,
        _ rhs: Range<Int>,
        in bytes: UnsafeRawBufferPointer
    ) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for offset in 0..<lhs.count
        where bytes[lhs.lowerBound + offset] != bytes[rhs.lowerBound + offset] {
            return false
        }
        return true
    }

    private func readingRange(
        at index: Int,
        in bytes: UnsafeRawBufferPointer
    ) -> Range<Int> {
        let start = readingOffsets[index]
        var end = start
        while end < bytes.count, bytes[end] != 0x09, bytes[end] != 0x0A {
            end += 1
        }
        return start..<end
    }

    private func candidates(
        at index: Int,
        limit: Int,
        in bytes: UnsafeRawBufferPointer
    ) -> [String] {
        guard limit > 0 else {
            return []
        }
        let expectedReading = readingRange(at: index, in: bytes)
        var position = readingOffsets[index]
        var seen = Set<String>()
        var result: [String] = []

        while position < bytes.count {
            let start = position
            var end = start
            while end < bytes.count, bytes[end] != 0x0A {
                end += 1
            }
            position = end < bytes.count ? end + 1 : end
            guard start < end else {
                continue
            }
            var tab = start
            while tab < end, bytes[tab] != 0x09 {
                tab += 1
            }
            guard tab < end,
                  Self.equal(start..<tab, expectedReading, in: bytes) else {
                break
            }
            let valueStart = tab + 1
            var valueEnd = end
            while valueEnd > valueStart,
                  bytes[valueEnd - 1] == 0x0D || bytes[valueEnd - 1] == 0x20 {
                valueEnd -= 1
            }
            guard valueStart < valueEnd,
                  let value = String(
                    bytes: UnsafeRawBufferPointer(
                        rebasing: bytes[valueStart..<valueEnd]
                    ),
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

    private func reading(at index: Int) -> Data.SubSequence {
        let start = readingOffsets[index]
        var end = start
        while end < data.count, data[end] != 0x09, data[end] != 0x0A {
            end += 1
        }
        return data[start..<end]
    }

    private func lineEnd(startingAt start: Int) -> Int {
        var end = start
        while end < data.count, data[end] != 0x0A {
            end += 1
        }
        return end
    }
}

/// The latest prefix lookups, used from the main thread and from
/// background searches alike
private final class GroupCache: @unchecked Sendable {
    struct Key: Hashable {
        let prefix: String
        let limit: Int
    }

    private static let capacity = 32
    private let lock = NSLock()
    private var values: [Key: DictionaryCandidateGroups] = [:]
    private var order: [Key] = []

    func value(for key: Key) -> DictionaryCandidateGroups? {
        lock.lock()
        defer { lock.unlock() }
        return values[key]
    }

    func store(_ value: DictionaryCandidateGroups, for key: Key) {
        lock.lock()
        defer { lock.unlock() }
        guard values.updateValue(value, forKey: key) == nil else { return }
        order.append(key)
        if order.count > Self.capacity {
            values[order.removeFirst()] = nil
        }
    }
}
