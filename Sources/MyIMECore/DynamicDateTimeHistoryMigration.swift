import Foundation

public enum DynamicDateTimeHistoryMigration {
    public static let version = 1

    public struct ProtectedEntry: Hashable, Sendable {
        public let reading: String
        public let candidate: String

        public init(reading: String, candidate: String) {
            self.reading = reading.lowercased()
            self.candidate = candidate
        }
    }

    public struct Report: Codable, Equatable, Sendable {
        public let version: Int
        public let examinedAssociationCount: Int
        public let removedAssociationCount: Int
        public let removedCandidateCount: Int
        public let retainedProtectedCount: Int
        public let unclassifiedAssociationCount: Int

        public init(
            examinedAssociationCount: Int,
            removedAssociationCount: Int,
            removedCandidateCount: Int,
            retainedProtectedCount: Int,
            unclassifiedAssociationCount: Int
        ) {
            version = DynamicDateTimeHistoryMigration.version
            self.examinedAssociationCount = examinedAssociationCount
            self.removedAssociationCount = removedAssociationCount
            self.removedCandidateCount = removedCandidateCount
            self.retainedProtectedCount = retainedProtectedCount
            self.unclassifiedAssociationCount = unclassifiedAssociationCount
        }
    }

    public struct Result: Equatable, Sendable {
        public let history: CandidateSelectionHistory
        public let report: Report
    }

    private static let dateReadings: Set<String> = [
        "ototoi", "sakujitu", "kinou", "kyou", "asu", "ashita", "asatte"
    ]
    private static let timeReadings: Set<String> = [
        "ima", "jikoku", "genzaijikoku"
    ]
    private static let dateTimeReadings: Set<String> = [
        "nichiji", "genzainichiji"
    ]

    public static func migrate(
        _ history: CandidateSelectionHistory,
        protecting protectedEntries: Set<ProtectedEntry> = []
    ) -> Result {
        var migrated = history
        var examined = 0
        var removedAssociations = 0
        var protectedCount = 0
        var unclassified = 0
        var removedCandidates = Set<String>()

        for reading in (dateReadings.union(timeReadings).union(dateTimeReadings)).sorted() {
            let candidates = history.recordedCandidates(for: reading)
            examined += candidates.count
            for candidate in candidates {
                guard isKnownDynamicOutput(candidate, for: reading) else {
                    unclassified += 1
                    continue
                }
                guard !protectedEntries.contains(.init(
                    reading: reading,
                    candidate: candidate
                )) else {
                    protectedCount += 1
                    continue
                }
                let removed = migrated.remove([candidate], forReading: reading)
                if removed > 0 {
                    removedAssociations += removed
                    removedCandidates.insert(candidate)
                }
            }
        }
        return Result(
            history: migrated,
            report: Report(
                examinedAssociationCount: examined,
                removedAssociationCount: removedAssociations,
                removedCandidateCount: removedCandidates.count,
                retainedProtectedCount: protectedCount,
                unclassifiedAssociationCount: unclassified
            )
        )
    }

    private static func isKnownDynamicOutput(
        _ candidate: String,
        for reading: String
    ) -> Bool {
        if dateReadings.contains(reading) {
            return isDate(candidate)
        }
        if timeReadings.contains(reading) {
            return isTime(candidate)
        }
        if dateTimeReadings.contains(reading) {
            return isDateTime(candidate)
        }
        return false
    }

    private static func isDate(_ value: String) -> Bool {
        if value.count == 8, let number = Int(value) {
            return validDate(
                year: number / 10_000,
                month: number / 100 % 100,
                day: number % 100
            )
        }
        if let parts = dateParts(value, separator: "-")
            ?? dateParts(value, separator: "/") {
            return validDate(year: parts.0, month: parts.1, day: parts.2)
        }
        if value.hasSuffix("日"),
           let yearEnd = value.firstIndex(of: "年"),
           let monthEnd = value.firstIndex(of: "月"),
           yearEnd < monthEnd,
           let year = Int(value[..<yearEnd]),
           let month = Int(value[value.index(after: yearEnd)..<monthEnd]),
           let day = Int(value[value.index(after: monthEnd)..<value.index(before: value.endIndex)]) {
            return validDate(year: year, month: month, day: day)
        }
        guard value.hasSuffix(")"),
              let open = value.lastIndex(of: "("),
              value.distance(from: open, to: value.index(before: value.endIndex)) == 2,
              let parts = monthDayParts(String(value[..<open])) else {
            return false
        }
        return validMonthDay(month: parts.0, day: parts.1)
    }

    private static func isTime(_ value: String) -> Bool {
        if let parts = clockParts(value, separator: ":") {
            return validTime(hour: parts.0, minute: parts.1, second: parts.2)
        }
        if value.hasSuffix("秒"), let parts = japaneseTimeParts(value) {
            return validTime(hour: parts.0, minute: parts.1, second: parts.2)
        }
        if value.hasSuffix("分"), let parts = japaneseTimeParts(value) {
            return validTime(hour: parts.0, minute: parts.1, second: nil)
        }
        guard value.allSatisfy(\.isNumber), value.count == 4 || value.count == 6,
              let number = Int(value) else { return false }
        if value.count == 4 {
            return validTime(hour: number / 100, minute: number % 100, second: nil)
        }
        return validTime(
            hour: number / 10_000,
            minute: number / 100 % 100,
            second: number % 100
        )
    }

    private static func isDateTime(_ value: String) -> Bool {
        if value.count == 14, value.allSatisfy(\.isNumber), let number = Int(value) {
            return validDate(
                year: number / 10_000_000_000,
                month: number / 100_000_000 % 100,
                day: number / 1_000_000 % 100
            ) && validTime(
                hour: number / 10_000 % 100,
                minute: number / 100 % 100,
                second: number % 100
            )
        }
        let components = value.split(separator: " ", maxSplits: 1).map(String.init)
        return components.count == 2
            && isDate(components[0])
            && isTime(components[1])
    }

    private static func dateParts(
        _ value: String,
        separator: Character
    ) -> (Int, Int, Int)? {
        let parts = value.split(separator: separator, omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return nil }
        return (year, month, day)
    }

    private static func monthDayParts(_ value: String) -> (Int, Int)? {
        let parts = value.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let month = Int(parts[0]),
              let day = Int(parts[1]) else { return nil }
        return (month, day)
    }

    private static func clockParts(
        _ value: String,
        separator: Character
    ) -> (Int, Int, Int?)? {
        let parts = value.split(separator: separator, omittingEmptySubsequences: false)
        guard parts.count == 2 || parts.count == 3,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }
        let second = parts.count == 3 ? Int(parts[2]) : nil
        guard parts.count == 2 || second != nil else { return nil }
        return (hour, minute, second)
    }

    private static func japaneseTimeParts(_ value: String) -> (Int, Int, Int?)? {
        guard let hourEnd = value.firstIndex(of: "時"),
              let minuteEnd = value.firstIndex(of: "分"),
              hourEnd < minuteEnd,
              let hour = Int(value[..<hourEnd]),
              let minute = Int(value[value.index(after: hourEnd)..<minuteEnd]) else {
            return nil
        }
        if value.hasSuffix("秒") {
            let secondStart = value.index(after: minuteEnd)
            let secondEnd = value.index(before: value.endIndex)
            guard let second = Int(value[secondStart..<secondEnd]) else { return nil }
            return (hour, minute, second)
        }
        return (hour, minute, nil)
    }

    private static func validDate(year: Int, month: Int, day: Int) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day
        )) else { return false }
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return parts.year == year && parts.month == month && parts.day == day
    }

    private static func validMonthDay(month: Int, day: Int) -> Bool {
        validDate(year: 2000, month: month, day: day)
    }

    private static func validTime(hour: Int, minute: Int, second: Int?) -> Bool {
        (0..<24).contains(hour)
            && (0..<60).contains(minute)
            && second.map { (0..<60).contains($0) } != false
    }
}

public enum DynamicDateTimeHistoryMigrationRunner {
    public static func migrateIfNeeded(
        historyURL: URL,
        backupURL: URL,
        markerURL: URL,
        protecting protectedEntries: Set<DynamicDateTimeHistoryMigration.ProtectedEntry> = [],
        fileManager: FileManager = .default
    ) throws -> DynamicDateTimeHistoryMigration.Report? {
        guard !fileManager.fileExists(atPath: markerURL.path) else { return nil }
        let data = try Data(contentsOf: historyURL)
        let decoder = JSONDecoder()
        let history: CandidateSelectionHistory
        if let decoded = try? decoder.decode(CandidateSelectionHistory.self, from: data) {
            history = decoded
        } else if let ranks = try? decoder.decode([String: Int].self, from: data) {
            history = CandidateSelectionHistory(ranks: ranks)
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let result = DynamicDateTimeHistoryMigration.migrate(
            history,
            protecting: protectedEntries
        )
        try fileManager.createDirectory(
            at: historyURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if result.report.removedAssociationCount > 0 {
            if !fileManager.fileExists(atPath: backupURL.path) {
                try data.write(to: backupURL, options: .atomic)
                try fileManager.setAttributes(
                    [.posixPermissions: 0o600],
                    ofItemAtPath: backupURL.path
                )
                guard try Data(contentsOf: backupURL) == data else {
                    throw CocoaError(.fileWriteUnknown)
                }
            }
            try JSONEncoder().encode(result.history).write(
                to: historyURL,
                options: .atomic
            )
        }
        try JSONEncoder().encode(result.report).write(
            to: markerURL,
            options: .atomic
        )
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: markerURL.path
        )
        return result.report
    }
}
