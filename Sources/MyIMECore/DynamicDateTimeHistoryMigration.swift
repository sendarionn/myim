import Foundation

public enum DynamicDateTimeHistoryMigration {
    public static let version = 2

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
        public let migratedPreferenceCount: Int
        public let retainedProtectedCount: Int
        public let unclassifiedAssociationCount: Int

        public init(
            examinedAssociationCount: Int,
            removedAssociationCount: Int,
            removedCandidateCount: Int,
            migratedPreferenceCount: Int,
            retainedProtectedCount: Int,
            unclassifiedAssociationCount: Int
        ) {
            version = DynamicDateTimeHistoryMigration.version
            self.examinedAssociationCount = examinedAssociationCount
            self.removedAssociationCount = removedAssociationCount
            self.removedCandidateCount = removedCandidateCount
            self.migratedPreferenceCount = migratedPreferenceCount
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
        recoveringPreferencesFrom legacyHistory: CandidateSelectionHistory? = nil,
        protecting protectedEntries: Set<ProtectedEntry> = []
    ) -> Result {
        var migrated = history
        let preferenceSource = legacyHistory ?? history
        var examined = 0
        var removedAssociations = 0
        var protectedCount = 0
        var unclassified = 0
        var removedCandidates = Set<String>()
        var migratedPreferences = Set<String>()

        for reading in (dateReadings.union(timeReadings).union(dateTimeReadings)).sorted() {
            let candidates = preferenceSource.recordedCandidates(for: reading)
            examined += candidates.count
            for candidate in candidates {
                guard let preferenceID = preferenceID(
                    candidate,
                    reading: reading
                ) else {
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
                if let rank = preferenceSource.ranks[candidate] {
                    migrated.preserveRank(rank, for: preferenceID)
                    migratedPreferences.insert(preferenceID)
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
                migratedPreferenceCount: migratedPreferences.count,
                retainedProtectedCount: protectedCount,
                unclassifiedAssociationCount: unclassified
            )
        )
    }

    private static func preferenceID(
        _ candidate: String,
        reading: String
    ) -> String? {
        if dateReadings.contains(reading) {
            return dateFormat(of: candidate).map {
                "dynamic_date:\(reading):\($0)"
            }
        }
        if timeReadings.contains(reading) {
            return timeFormat(of: candidate).map {
                "dynamic_time:\(reading):\($0)"
            }
        }
        if dateTimeReadings.contains(reading) {
            return dateTimeFormat(of: candidate).map {
                "dynamic_datetime:\(reading):\($0)"
            }
        }
        return nil
    }

    private static func dateFormat(of value: String) -> String? {
        if value.count == 8, let number = Int(value) {
            return validDate(
                year: number / 10_000,
                month: number / 100 % 100,
                day: number % 100
            ) ? "YYYYMMDD" : nil
        }
        if let parts = dateParts(value, separator: "-") {
            return validDate(year: parts.0, month: parts.1, day: parts.2)
                ? "YYYY-MM-DD" : nil
        }
        if let parts = dateParts(value, separator: "/") {
            return validDate(year: parts.0, month: parts.1, day: parts.2)
                ? "YYYY/MM/DD" : nil
        }
        if value.hasSuffix("日"),
           let yearEnd = value.firstIndex(of: "年"),
           let monthEnd = value.firstIndex(of: "月"),
           yearEnd < monthEnd,
           let year = Int(value[..<yearEnd]),
           let month = Int(value[value.index(after: yearEnd)..<monthEnd]),
           let day = Int(value[value.index(after: monthEnd)..<value.index(before: value.endIndex)]) {
            return validDate(year: year, month: month, day: day)
                ? "YYYY年M月D日" : nil
        }
        guard value.hasSuffix(")"),
              let open = value.lastIndex(of: "("),
              value.distance(from: open, to: value.index(before: value.endIndex)) == 2,
              let parts = monthDayParts(String(value[..<open])) else {
            return nil
        }
        return validMonthDay(month: parts.0, day: parts.1)
            ? "M/D(E)" : nil
    }

    private static func timeFormat(of value: String) -> String? {
        if let parts = clockParts(value, separator: ":") {
            guard validTime(
                hour: parts.hour,
                minute: parts.minute,
                second: parts.second
            ) else { return nil }
            let hourToken = parts.hourWidth == 2 ? "HH" : "H"
            let minuteToken = parts.minuteWidth == 2 ? "mm" : "m"
            if let secondWidth = parts.secondWidth {
                return "\(hourToken):\(minuteToken):\(secondWidth == 2 ? "ss" : "s")"
            }
            return "\(hourToken):\(minuteToken)"
        }
        if value.hasSuffix("秒"), let parts = japaneseTimeParts(value) {
            return validTime(hour: parts.0, minute: parts.1, second: parts.2)
                ? "H時m分s秒" : nil
        }
        if value.hasSuffix("分"), let parts = japaneseTimeParts(value) {
            return validTime(hour: parts.0, minute: parts.1, second: nil)
                ? "H時m分" : nil
        }
        guard value.allSatisfy(\.isNumber), value.count == 4 || value.count == 6,
              let number = Int(value) else { return nil }
        if value.count == 4 {
            return validTime(hour: number / 100, minute: number % 100, second: nil)
                ? "HHmm" : nil
        }
        return validTime(
            hour: number / 10_000,
            minute: number / 100 % 100,
            second: number % 100
        ) ? "HHmmss" : nil
    }

    private static func dateTimeFormat(of value: String) -> String? {
        if value.count == 14, value.allSatisfy(\.isNumber), let number = Int(value) {
            let valid = validDate(
                year: number / 10_000_000_000,
                month: number / 100_000_000 % 100,
                day: number / 1_000_000 % 100
            ) && validTime(
                hour: number / 10_000 % 100,
                minute: number / 100 % 100,
                second: number % 100
            )
            return valid ? "YYYYMMDDHHmmss" : nil
        }
        let components = value.split(separator: " ", maxSplits: 1).map(String.init)
        guard components.count == 2,
              let date = dateFormat(of: components[0]),
              let time = timeFormat(of: components[1]) else { return nil }
        return "\(date) \(time)"
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
    ) -> (
        hour: Int,
        minute: Int,
        second: Int?,
        hourWidth: Int,
        minuteWidth: Int,
        secondWidth: Int?
    )? {
        let parts = value.split(separator: separator, omittingEmptySubsequences: false)
        guard parts.count == 2 || parts.count == 3,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }
        let second = parts.count == 3 ? Int(parts[2]) : nil
        guard parts.count == 2 || second != nil else { return nil }
        return (
            hour,
            minute,
            second,
            parts[0].count,
            parts[1].count,
            parts.count == 3 ? parts[2].count : nil
        )
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
        legacySourceURL: URL? = nil,
        protecting protectedEntries: Set<DynamicDateTimeHistoryMigration.ProtectedEntry> = [],
        fileManager: FileManager = .default
    ) throws -> DynamicDateTimeHistoryMigration.Report? {
        guard !fileManager.fileExists(atPath: markerURL.path) else { return nil }
        let data = try Data(contentsOf: historyURL)
        let history = try decodeHistory(data)
        let legacyHistory: CandidateSelectionHistory?
        if let legacySourceURL,
           fileManager.fileExists(atPath: legacySourceURL.path) {
            legacyHistory = try decodeHistory(
                Data(contentsOf: legacySourceURL)
            )
        } else {
            legacyHistory = nil
        }
        let result = DynamicDateTimeHistoryMigration.migrate(
            history,
            recoveringPreferencesFrom: legacyHistory,
            protecting: protectedEntries
        )
        try fileManager.createDirectory(
            at: historyURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if result.history != history {
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

    private static func decodeHistory(
        _ data: Data
    ) throws -> CandidateSelectionHistory {
        let decoder = JSONDecoder()
        if let history = try? decoder.decode(
            CandidateSelectionHistory.self,
            from: data
        ) {
            return history
        }
        if let ranks = try? decoder.decode([String: Int].self, from: data) {
            return CandidateSelectionHistory(ranks: ranks)
        }
        throw CocoaError(.fileReadCorruptFile)
    }
}
