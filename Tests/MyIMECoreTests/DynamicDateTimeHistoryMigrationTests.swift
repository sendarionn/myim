import Foundation
import Testing
@testable import MyIMECore

@Suite
struct DynamicDateTimeHistoryMigrationTests {
    @Test
    func removesOnlyKnownDynamicFormatsFromDynamicReadings() {
        var history = CandidateSelectionHistory()
        history.record("20261012", reading: "kyou")
        history.record("20261012", reading: "kyou")
        history.record("今日", reading: "kyou")
        history.record("2026-10-12", reading: "ashita")
        history.record("2026-10-12", reading: "ashita")
        history.record("10:31", reading: "ima")
        history.record("10:31", reading: "ima")
        history.record("固定日付", reading: "kyou")
        history.record("20261012", reading: "fixed")
        history.record("20261012", reading: "fixed")

        let result = DynamicDateTimeHistoryMigration.migrate(history)

        #expect(result.history.ranks(for: "kyou")["20261012"] == nil)
        #expect(result.history.ranks(for: "ashita")["2026-10-12"] == nil)
        #expect(result.history.ranks(for: "ima")["10:31"] == nil)
        #expect(result.history.ranks(for: "kyou")["今日"] != nil)
        #expect(result.history.ranks(for: "kyou")["固定日付"] != nil)
        #expect(result.history.ranks(for: "fixed")["20261012"] != nil)
        #expect(
            result.history.ranks["dynamic_date:kyou:YYYYMMDD"] != nil
        )
        #expect(
            result.history.ranks["dynamic_date:ashita:YYYY-MM-DD"] != nil
        )
        #expect(result.history.ranks["dynamic_time:ima:HH:mm"] != nil)
        #expect(result.report.removedAssociationCount == 3)
        #expect(result.report.migratedPreferenceCount == 3)
        #expect(result.report.unclassifiedAssociationCount == 2)
    }

    @Test
    func protectsExplicitUserDictionaryEntries() {
        var history = CandidateSelectionHistory()
        history.record("20261031", reading: "kyou")
        history.record("20261031", reading: "kyou")

        let result = DynamicDateTimeHistoryMigration.migrate(
            history,
            protecting: [.init(reading: "kyou", candidate: "20261031")]
        )

        #expect(result.history.ranks(for: "kyou")["20261031"] != nil)
        #expect(result.history.ranks["dynamic_date:kyou:YYYYMMDD"] == nil)
        #expect(result.report.removedAssociationCount == 0)
        #expect(result.report.migratedPreferenceCount == 0)
        #expect(result.report.retainedProtectedCount == 1)
    }

    @Test
    func runnerBacksUpAndRunsOnlyOnce() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let historyURL = directory.appendingPathComponent("history.json")
        let backupURL = directory.appendingPathComponent("history.backup.json")
        let markerURL = directory.appendingPathComponent("migration.json")
        var history = CandidateSelectionHistory()
        history.record("20261031", reading: "kyou")
        let original = try JSONEncoder().encode(history)
        try original.write(to: historyURL)

        let migration = try DynamicDateTimeHistoryMigrationRunner
            .migrateIfNeeded(
                historyURL: historyURL,
                backupURL: backupURL,
                markerURL: markerURL
            )
        let first = try #require(migration)
        let second = try DynamicDateTimeHistoryMigrationRunner.migrateIfNeeded(
            historyURL: historyURL,
            backupURL: backupURL,
            markerURL: markerURL
        )
        let migrated = try JSONDecoder().decode(
            CandidateSelectionHistory.self,
            from: Data(contentsOf: historyURL)
        )

        #expect(first.removedAssociationCount == 1)
        #expect(first.migratedPreferenceCount == 1)
        #expect(second == nil)
        #expect(try Data(contentsOf: backupURL) == original)
        #expect(migrated.ranks(for: "kyou").isEmpty)
        #expect(migrated.ranks["dynamic_date:kyou:YYYYMMDD"] != nil)
        let backupPermissions = try #require(
            FileManager.default.attributesOfItem(atPath: backupURL.path)[
                .posixPermissions
            ] as? NSNumber
        )
        let markerPermissions = try #require(
            FileManager.default.attributesOfItem(atPath: markerURL.path)[
                .posixPermissions
            ] as? NSNumber
        )
        #expect(backupPermissions.intValue == 0o600)
        #expect(markerPermissions.intValue == 0o600)
    }

    @Test
    func recoversPreferencesFromThePreviousMigrationBackup() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let historyURL = directory.appendingPathComponent("history.json")
        let legacyURL = directory.appendingPathComponent("migration-v1.json")
        let backupURL = directory.appendingPathComponent("migration-v2.json")
        let markerURL = directory.appendingPathComponent("marker-v2.json")
        var legacy = CandidateSelectionHistory()
        legacy.record("20261031", reading: "kyou")
        var current = legacy
        current.remove(["20261031"], forReading: "kyou")
        try JSONEncoder().encode(current).write(to: historyURL)
        try JSONEncoder().encode(legacy).write(to: legacyURL)

        let migration = try DynamicDateTimeHistoryMigrationRunner
            .migrateIfNeeded(
                historyURL: historyURL,
                backupURL: backupURL,
                markerURL: markerURL,
                legacySourceURL: legacyURL
            )
        let report = try #require(
            migration
        )
        let migrated = try JSONDecoder().decode(
            CandidateSelectionHistory.self,
            from: Data(contentsOf: historyURL)
        )

        #expect(report.removedAssociationCount == 0)
        #expect(report.migratedPreferenceCount == 1)
        #expect(migrated.ranks["dynamic_date:kyou:YYYYMMDD"] != nil)
        #expect(migrated.ranks["20261031"] == nil)
    }
}
