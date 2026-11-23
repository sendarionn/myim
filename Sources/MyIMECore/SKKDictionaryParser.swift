import Foundation

public struct SKKDictionaryImportResult: Equatable, Sendable {
    public let entries: [DictionaryEntry]
    /// Okuri-ari entries, keyed as in SKK by the stem and the okurigana's
    /// first letter (かk), kept apart from the ordinary entries
    public let okuriAriEntries: [DictionaryEntry]
    public let skippedEntryCount: Int

    public init(
        entries: [DictionaryEntry],
        okuriAriEntries: [DictionaryEntry] = [],
        skippedEntryCount: Int
    ) {
        self.entries = entries
        self.okuriAriEntries = okuriAriEntries
        self.skippedEntryCount = skippedEntryCount
    }
}

public struct SKKDictionaryParser: Sendable {
    public init() {}

    public func parse(_ text: String) -> SKKDictionaryImportResult {
        var order: [String] = []
        var candidatesByReading: [String: [String]] = [:]
        var okuriAriOrder: [String] = []
        var okuriAriByKey: [String: [String]] = [:]
        var skippedEntryCount = 0

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix(";;") else { continue }
            guard let separator = line.firstIndex(where: { $0.isWhitespace }) else {
                skippedEntryCount += 1
                continue
            }
            let reading = String(line[..<separator])
            let candidateList = line[separator...]
                .trimmingCharacters(in: .whitespaces)
            guard candidateList.first == "/", candidateList.last == "/" else {
                skippedEntryCount += 1
                continue
            }
            guard isOkuriNasi(reading) else {
                let candidates = parseCandidates(candidateList)
                guard isOkuriAri(reading), !candidates.isEmpty else {
                    skippedEntryCount += 1
                    continue
                }
                if okuriAriByKey[reading] == nil {
                    okuriAriOrder.append(reading)
                }
                for candidate in candidates
                where okuriAriByKey[reading, default: []].contains(candidate) == false {
                    okuriAriByKey[reading, default: []].append(candidate)
                }
                continue
            }
            let candidates = parseCandidates(candidateList)
            guard !candidates.isEmpty else {
                skippedEntryCount += 1
                continue
            }
            if candidatesByReading[reading] == nil {
                order.append(reading)
                candidatesByReading[reading] = []
            }
            for candidate in candidates
            where candidatesByReading[reading]?.contains(candidate) == false {
                candidatesByReading[reading]?.append(candidate)
            }
        }

        return SKKDictionaryImportResult(
            entries: order.map {
                DictionaryEntry(
                    reading: $0,
                    candidates: candidatesByReading[$0] ?? []
                )
            },
            okuriAriEntries: okuriAriOrder.map {
                DictionaryEntry(reading: $0, candidates: okuriAriByKey[$0] ?? [])
            },
            skippedEntryCount: skippedEntryCount
        )
    }

    /// Kana followed by one ASCII letter, as かk
    private func isOkuriAri(_ reading: String) -> Bool {
        guard let last = reading.unicodeScalars.last,
              last.isASCII, CharacterSet.letters.contains(last) else { return false }
        let stem = reading.unicodeScalars.dropLast()
        return !stem.isEmpty && stem.allSatisfy { (0x3040...0x30FF).contains($0.value) }
    }

    private func isOkuriNasi(_ reading: String) -> Bool {
        guard let last = reading.unicodeScalars.last else { return false }
        guard last.isASCII && CharacterSet.letters.contains(last) else {
            return true
        }
        return !reading.unicodeScalars.dropLast().contains {
            (0x3040...0x30FF).contains($0.value)
        }
    }

    private func parseCandidates(_ source: String) -> [String] {
        var rawCandidates: [String] = []
        var current = ""
        var escaped = false
        for character in source.dropFirst().dropLast() {
            if escaped {
                current.append("\\")
                current.append(character)
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "/" {
                rawCandidates.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        if escaped { current.append("\\") }
        rawCandidates.append(current)

        var seen = Set<String>()
        return rawCandidates.compactMap { rawCandidate in
            let withoutAnnotation = removingAnnotation(from: rawCandidate)
            let candidate = decodeEscapes(in: withoutAnnotation)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !candidate.isEmpty,
                  !candidate.hasPrefix("("),
                  !candidate.hasPrefix("["),
                  !candidate.hasSuffix("]"),
                  seen.insert(candidate).inserted else {
                return nil
            }
            return candidate
        }
    }

    private func removingAnnotation(from source: String) -> String {
        var escaped = false
        for index in source.indices {
            let character = source[index]
            if escaped {
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == ";" {
                return String(source[..<index])
            }
        }
        return source
    }

    private func decodeEscapes(in source: String) -> String {
        let characters = Array(source)
        var result = ""
        var index = 0
        while index < characters.count {
            guard characters[index] == "\\", index + 1 < characters.count else {
                result.append(characters[index])
                index += 1
                continue
            }
            if index + 3 < characters.count {
                let digits = String(characters[(index + 1)...(index + 3)])
                if digits.allSatisfy({ ("0"..."7").contains(String($0)) }),
                   let value = UInt32(digits, radix: 8),
                   let scalar = UnicodeScalar(value) {
                    result.unicodeScalars.append(scalar)
                    index += 4
                    continue
                }
            }
            result.append(characters[index + 1])
            index += 2
        }
        return result
    }
}
