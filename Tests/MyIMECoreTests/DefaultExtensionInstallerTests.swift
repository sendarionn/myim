import Foundation
import Testing
@testable import MyIMECore

@Suite("DefaultExtensionInstallerTests")
struct DefaultExtensionInstallerTests {
    @Test
    func removesDeprecatedDateTimeReadingsWithoutChangingOtherFormats() throws {
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

        try DefaultExtensionInstaller.installIfNeeded(from: source, into: destination)

        let migrated = try String(contentsOf: installed, encoding: .utf8)
        #expect(migrated.contains("dateFormats"))
        #expect(!migrated.contains("dateTimeFormats"))
        #expect(!migrated.contains("dateTimeReadings"))
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
}
