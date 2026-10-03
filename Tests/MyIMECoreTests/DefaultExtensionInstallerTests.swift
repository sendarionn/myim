import Foundation
import Testing
@testable import MyIMECore

@Suite("DefaultExtensionInstallerTests")
struct DefaultExtensionInstallerTests {
    @Test
    func removesDeprecatedDefaultSymbolsExtension() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let source = root.appendingPathComponent("source", isDirectory: true)
        let destination = root.appendingPathComponent("destination", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let installed = destination.appendingPathComponent("symbols.js")
        try Data("""
        function candidates(context) {
          const input = context.input.toLowerCase()
          return symbolNames[input] || []
        }

        const symbolNames = {
          "ongusutoro-mu": ["Å"],
          "ongusutoroomu": ["Å"],
          "be-ta": ["β"],
          "beeta": ["β"]
        }
        """.utf8).write(to: installed)

        try DefaultExtensionInstaller.installIfNeeded(from: source, into: destination)

        #expect(!FileManager.default.fileExists(atPath: installed.path))
    }

    @Test
    func preservesCustomizedSymbolsExtension() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let source = root.appendingPathComponent("source", isDirectory: true)
        let destination = root.appendingPathComponent("destination", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let installed = destination.appendingPathComponent("symbols.js")
        try Data("function candidates() { return [\"custom\"] }".utf8).write(to: installed)

        try DefaultExtensionInstaller.installIfNeeded(from: source, into: destination)

        #expect(FileManager.default.fileExists(atPath: installed.path))
    }

    @Test
    func protectsUnknownLegacyNumericExtension() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let source = root.appendingPathComponent("source", isDirectory: true)
        let destination = root.appendingPathComponent("destination", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try Data("current bundled numeric tools".utf8).write(
            to: source.appendingPathComponent("numeric-tools.js")
        )
        let installed = destination.appendingPathComponent("numeric-tools.js")
        try Data("""
          const sign = value < 0 ? "-" : ""
          return [sign + "0b" + Math.abs(value).toString(2)]
        """.utf8).write(to: installed)

        let report = try DefaultExtensionInstaller.installIfNeeded(
            from: source,
            into: destination
        )

        let migrated = try String(contentsOf: installed, encoding: .utf8)
        #expect(migrated.contains("0b"))
        #expect(report.conflicts.map(\.fileName) == ["numeric-tools.js"])
    }

    @Test
    func removesDeprecatedCalendarEventExtension() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let source = root.appendingPathComponent("source", isDirectory: true)
        let destination = root.appendingPathComponent("destination", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let calendarExtension = destination.appendingPathComponent("calendar.js")
        try Data("""
        function candidates(context) {
          if (context.input === "calendar-event") return context.calendarEvents.map(formatCalendarEvent)
        }
        function formatCalendarEvent(event) { return event.title }
        """.utf8).write(to: calendarExtension)

        try DefaultExtensionInstaller.installIfNeeded(from: source, into: destination)

        #expect(!FileManager.default.fileExists(atPath: calendarExtension.path))
    }

    @Test
    func protectsUnknownCustomizedDateTimeExtension() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let source = root.appendingPathComponent("source", isDirectory: true)
        let destination = root.appendingPathComponent("destination", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try Data("function candidates() { return [] }\n".utf8).write(
            to: source.appendingPathComponent("datetime.js")
        )
        let installed = destination.appendingPathComponent("datetime.js")
        let customized = """
          const dateFormats = ["YYYYMMDD"]
          const dateTimeFormats = [
            "YYYY-MM-DD-THHmmss"
          ]
          const dateTimeReadings = ["nichiji", "genzainichiji"]
          if (dateTimeReadings.indexOf(input) >= 0) {
            return format(now, dateTimeFormats)
          }
        """ + "\n"
        try Data(customized.utf8).write(to: installed)

        let report = try DefaultExtensionInstaller.installIfNeeded(
            from: source,
            into: destination
        )

        let migrated = try String(contentsOf: installed, encoding: .utf8)
        #expect(migrated.contains("dateFormats"))
        #expect(migrated.contains("dateTimeFormats"))
        #expect(migrated.contains("dateTimeReadings"))
        #expect(report.conflicts.map(\.fileName) == ["datetime.js"])
    }

    @Test
    func installsDefaultsOnlyOnceWithoutOverwritingUserChanges() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let source = root.appendingPathComponent("source", isDirectory: true)
        let destination = root.appendingPathComponent(
            "destination",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: source,
            withIntermediateDirectories: true
        )
        let sourceScript = source.appendingPathComponent("datetime.js")
        try Data("original".utf8).write(to: sourceScript)

        try DefaultExtensionInstaller.installIfNeeded(
            from: source,
            into: destination
        )
        let installed = destination.appendingPathComponent("datetime.js")
        #expect(try String(contentsOf: installed, encoding: .utf8) == "original")

        try Data("customized".utf8).write(to: installed)
        try Data("updated default".utf8).write(to: sourceScript)
        try DefaultExtensionInstaller.installIfNeeded(
            from: source,
            into: destination
        )

        #expect(try String(contentsOf: installed, encoding: .utf8) == "customized")
    }

    @Test
    func preservesExistingScriptDuringFirstInstallation() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let source = root.appendingPathComponent("source", isDirectory: true)
        let destination = root.appendingPathComponent(
            "destination",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: source,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: destination,
            withIntermediateDirectories: true
        )
        try Data("default".utf8).write(
            to: source.appendingPathComponent("datetime.js")
        )
        let existing = destination.appendingPathComponent("datetime.js")
        try Data("user version".utf8).write(to: existing)

        try DefaultExtensionInstaller.installIfNeeded(
            from: source,
            into: destination
        )

        #expect(try String(contentsOf: existing, encoding: .utf8) == "user version")
    }

    @Test
    func upgradesAnUnmodifiedPreviousDefault() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let source = root.appendingPathComponent("source", isDirectory: true)
        let destination = root.appendingPathComponent("destination", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try Data("new default".utf8).write(
            to: source.appendingPathComponent("datetime.js")
        )
        try Data("old default".utf8).write(
            to: source.appendingPathComponent("datetime.js.previous")
        )
        let installed = destination.appendingPathComponent("datetime.js")
        try Data("old default".utf8).write(to: installed)

        try DefaultExtensionInstaller.installIfNeeded(from: source, into: destination)

        #expect(try String(contentsOf: installed, encoding: .utf8) == "new default")
    }

    @Test
    func automaticallyUpdatesAnInstalledBundledExtension() throws {
        let directories = try makeDirectories()
        defer { try? FileManager.default.removeItem(at: directories.root) }
        let source = directories.source.appendingPathComponent("datetime.js")
        try Data("old bundled".utf8).write(to: source)
        try DefaultExtensionInstaller.installIfNeeded(
            from: directories.source,
            into: directories.destination
        )

        try Data("new bundled".utf8).write(to: source)
        let report = try DefaultExtensionInstaller.installIfNeeded(
            from: directories.source,
            into: directories.destination
        )

        let local = directories.destination.appendingPathComponent("datetime.js")
        #expect(try String(contentsOf: local, encoding: .utf8) == "new bundled")
        #expect(report.statuses == [DefaultExtensionStatus(
            fileName: "datetime.js",
            state: .bundledCurrent
        )])
    }

    @Test
    func reportsConflictWithoutOverwritingBothChangedExtension() throws {
        let directories = try makeDirectories()
        defer { try? FileManager.default.removeItem(at: directories.root) }
        let source = directories.source.appendingPathComponent("datetime.js")
        let local = directories.destination.appendingPathComponent("datetime.js")
        try Data("old bundled".utf8).write(to: source)
        try DefaultExtensionInstaller.installIfNeeded(
            from: directories.source,
            into: directories.destination
        )
        try Data("user edit".utf8).write(to: local)
        try Data("new bundled".utf8).write(to: source)

        let report = try DefaultExtensionInstaller.installIfNeeded(
            from: directories.source,
            into: directories.destination
        )

        #expect(try String(contentsOf: local, encoding: .utf8) == "user edit")
        #expect(report.conflicts.map(\.fileName) == ["datetime.js"])
    }

    @Test
    func leavesAUserEditAloneWhenBundledContentHasNotChanged() throws {
        let directories = try makeDirectories()
        defer { try? FileManager.default.removeItem(at: directories.root) }
        let source = directories.source.appendingPathComponent("datetime.js")
        let local = directories.destination.appendingPathComponent("datetime.js")
        try Data("bundled".utf8).write(to: source)
        try DefaultExtensionInstaller.installIfNeeded(
            from: directories.source,
            into: directories.destination
        )
        try Data("user edit".utf8).write(to: local)

        let report = try DefaultExtensionInstaller.installIfNeeded(
            from: directories.source,
            into: directories.destination
        )

        #expect(try String(contentsOf: local, encoding: .utf8) == "user edit")
        #expect(report.statuses.first?.state == .bundledModified)
        #expect(report.conflicts.isEmpty)
    }

    @Test
    func addsNewBundledExtensionWithoutTouchingUserExtension() throws {
        let directories = try makeDirectories()
        defer { try? FileManager.default.removeItem(at: directories.root) }
        let user = directories.destination.appendingPathComponent("custom.js")
        try Data("custom".utf8).write(to: user)
        try Data("default".utf8).write(
            to: directories.source.appendingPathComponent("datetime.js")
        )

        let report = try DefaultExtensionInstaller.installIfNeeded(
            from: directories.source,
            into: directories.destination
        )

        #expect(try String(contentsOf: user, encoding: .utf8) == "custom")
        #expect(report.statuses == [
            DefaultExtensionStatus(
                fileName: "custom.js",
                state: .userExtension
            ),
            DefaultExtensionStatus(
                fileName: "datetime.js",
                state: .bundledCurrent
            )
        ])
    }

    @Test
    func keepingAnUpdateSuppressesOnlyThatBundledVersion() throws {
        let directories = try makeDirectories()
        defer { try? FileManager.default.removeItem(at: directories.root) }
        let source = directories.source.appendingPathComponent("datetime.js")
        let local = directories.destination.appendingPathComponent("datetime.js")
        try Data("version 1".utf8).write(to: source)
        try DefaultExtensionInstaller.installIfNeeded(
            from: directories.source,
            into: directories.destination
        )
        try Data("user edit".utf8).write(to: local)
        try Data("version 2".utf8).write(to: source)

        let kept = try DefaultExtensionInstaller.resolveConflicts(
            fileNames: ["datetime.js"],
            resolution: .keep,
            from: directories.source,
            into: directories.destination
        )
        let repeated = try DefaultExtensionInstaller.installIfNeeded(
            from: directories.source,
            into: directories.destination
        )
        try Data("version 3".utf8).write(to: source)
        let newer = try DefaultExtensionInstaller.installIfNeeded(
            from: directories.source,
            into: directories.destination
        )

        #expect(kept.statuses.first?.state == .updateKept)
        #expect(repeated.conflicts.isEmpty)
        #expect(newer.conflicts.map(\.fileName) == ["datetime.js"])
        #expect(try String(contentsOf: local, encoding: .utf8) == "user edit")
    }

    @Test
    func updatingAConflictCreatesBackupAndRestoresAutomaticUpdates() throws {
        let directories = try makeDirectories()
        defer { try? FileManager.default.removeItem(at: directories.root) }
        let source = directories.source.appendingPathComponent("datetime.js")
        let local = directories.destination.appendingPathComponent("datetime.js")
        try Data("version 1".utf8).write(to: source)
        try DefaultExtensionInstaller.installIfNeeded(
            from: directories.source,
            into: directories.destination
        )
        try Data("user edit".utf8).write(to: local)
        try Data("version 2".utf8).write(to: source)

        let report = try DefaultExtensionInstaller.resolveConflicts(
            fileNames: ["datetime.js"],
            resolution: .update,
            from: directories.source,
            into: directories.destination,
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let files = try FileManager.default.contentsOfDirectory(
            at: directories.destination,
            includingPropertiesForKeys: nil
        )
        let backup = try #require(files.first {
            $0.lastPathComponent.hasPrefix("datetime.js.backup-")
        })

        #expect(try String(contentsOf: local, encoding: .utf8) == "version 2")
        #expect(try String(contentsOf: backup, encoding: .utf8) == "user edit")
        #expect(report.statuses.first?.state == .bundledCurrent)
    }

    @Test
    func failedConflictUpdateKeepsLocalFileAndPendingState() throws {
        let directories = try makeDirectories()
        defer { try? FileManager.default.removeItem(at: directories.root) }
        let source = directories.source.appendingPathComponent("datetime.js")
        let local = directories.destination.appendingPathComponent("datetime.js")
        try Data("version 1".utf8).write(to: source)
        try DefaultExtensionInstaller.installIfNeeded(
            from: directories.source,
            into: directories.destination
        )
        try Data("user edit".utf8).write(to: local)
        try Data("version 2".utf8).write(to: source)
        try FileManager.default.removeItem(at: source)

        #expect(throws: (any Error).self) {
            try DefaultExtensionInstaller.resolveConflicts(
                fileNames: ["datetime.js"],
                resolution: .update,
                from: directories.source,
                into: directories.destination
            )
        }
        try Data("version 2".utf8).write(to: source)
        let report = try DefaultExtensionInstaller.installIfNeeded(
            from: directories.source,
            into: directories.destination
        )

        #expect(try String(contentsOf: local, encoding: .utf8) == "user edit")
        #expect(report.conflicts.map(\.fileName) == ["datetime.js"])
    }

    @Test
    func resolvesOnlyTheSelectedConflict() throws {
        let directories = try makeDirectories()
        defer { try? FileManager.default.removeItem(at: directories.root) }
        for name in ["datetime.js", "numeric-tools.js"] {
            try Data("old \(name)".utf8).write(
                to: directories.source.appendingPathComponent(name)
            )
        }
        try DefaultExtensionInstaller.installIfNeeded(
            from: directories.source,
            into: directories.destination
        )
        for name in ["datetime.js", "numeric-tools.js"] {
            try Data("custom \(name)".utf8).write(
                to: directories.destination.appendingPathComponent(name)
            )
            try Data("new \(name)".utf8).write(
                to: directories.source.appendingPathComponent(name)
            )
        }

        let report = try DefaultExtensionInstaller.resolveConflicts(
            fileNames: ["datetime.js"],
            resolution: .update,
            from: directories.source,
            into: directories.destination
        )

        #expect(try String(
            contentsOf: directories.destination.appendingPathComponent(
                "datetime.js"
            ),
            encoding: .utf8
        ) == "new datetime.js")
        #expect(try String(
            contentsOf: directories.destination.appendingPathComponent(
                "numeric-tools.js"
            ),
            encoding: .utf8
        ) == "custom numeric-tools.js")
        #expect(report.conflicts.map(\.fileName) == ["numeric-tools.js"])
    }

    @Test
    func migratesKnownOldDateTimeWithoutTreatingItAsUserEdit() throws {
        let directories = try makeDirectories()
        defer { try? FileManager.default.removeItem(at: directories.root) }
        let source = directories.source.appendingPathComponent("datetime.js")
        let previous = directories.source.appendingPathComponent(
            "datetime.js.previous"
        )
        let local = directories.destination.appendingPathComponent("datetime.js")
        try Data("calendar capable".utf8).write(to: source)
        try Data("old bundled datetime".utf8).write(to: previous)
        try Data("old bundled datetime".utf8).write(to: local)

        let report = try DefaultExtensionInstaller.installIfNeeded(
            from: directories.source,
            into: directories.destination
        )

        #expect(try String(contentsOf: local, encoding: .utf8) == "calendar capable")
        #expect(report.statuses.first?.state == .bundledCurrent)
    }

    private func makeDirectories() throws -> (
        root: URL,
        source: URL,
        destination: URL
    ) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let source = root.appendingPathComponent("source", isDirectory: true)
        let destination = root.appendingPathComponent(
            "destination",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: source,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: destination,
            withIntermediateDirectories: true
        )
        return (root, source, destination)
    }
}
