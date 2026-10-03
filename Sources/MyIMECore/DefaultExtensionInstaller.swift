import CryptoKit
import Foundation

public enum DefaultExtensionUpdateState: Equatable, Sendable {
    case bundledCurrent
    case bundledModified
    case updateAvailable
    case updateKept
    case userExtension
}

public struct DefaultExtensionStatus: Equatable, Sendable {
    public let fileName: String
    public let state: DefaultExtensionUpdateState

    public init(fileName: String, state: DefaultExtensionUpdateState) {
        self.fileName = fileName
        self.state = state
    }
}

public struct DefaultExtensionInstallReport: Equatable, Sendable {
    public let statuses: [DefaultExtensionStatus]

    public init(statuses: [DefaultExtensionStatus]) {
        self.statuses = statuses
    }

    public var conflicts: [DefaultExtensionStatus] {
        statuses.filter { $0.state == .updateAvailable }
    }
}

public enum DefaultExtensionConflictResolution: Sendable {
    case update
    case keep
}

public enum DefaultExtensionInstaller {
    /// Retained only to avoid repeating cleanup of retired bundled extensions
    public static let markerName = ".myim-default-extensions-installed-v22"
    public static let manifestName = ".myim-default-extensions.json"

    private static let operationLock = NSLock()

    private struct Manifest: Codable, Equatable {
        var version = 1
        var entries: [String: Entry] = [:]
    }

    private struct Entry: Codable, Equatable {
        /// Bundled content from which an unmodified local file was installed
        var installedBundledHash: String?
        /// Bundled update which the user chose not to install
        var keptBundledHash: String?
    }

    @discardableResult
    public static func installIfNeeded(
        from sourceDirectory: URL,
        into destinationDirectory: URL,
        fileManager: FileManager = .default
    ) throws -> DefaultExtensionInstallReport {
        operationLock.lock()
        defer { operationLock.unlock() }
        return try install(
            from: sourceDirectory,
            into: destinationDirectory,
            fileManager: fileManager
        )
    }

    private static func install(
        from sourceDirectory: URL,
        into destinationDirectory: URL,
        fileManager: FileManager
    ) throws -> DefaultExtensionInstallReport {
        try fileManager.createDirectory(
            at: destinationDirectory,
            withIntermediateDirectories: true
        )
        var manifest = try loadManifest(from: destinationDirectory)
        let originalManifest = manifest
        let sourceFiles = try bundledScripts(
            in: sourceDirectory,
            fileManager: fileManager
        )
        var statuses: [DefaultExtensionStatus] = []

        for source in sourceFiles {
            let fileName = source.lastPathComponent
            let sourceData = try Data(contentsOf: source)
            let sourceHash = hash(sourceData)
            let destination = destinationDirectory
                .appendingPathComponent(fileName)
            let status = try reconcile(
                sourceData: sourceData,
                sourceHash: sourceHash,
                sourceDirectory: sourceDirectory,
                destination: destination,
                entry: &manifest.entries[fileName],
                fileManager: fileManager
            )
            statuses.append(DefaultExtensionStatus(
                fileName: fileName,
                state: status
            ))
        }

        try cleanUpRetiredDefaultsIfNeeded(
            in: destinationDirectory,
            fileManager: fileManager
        )
        let manifestURL = destinationDirectory.appendingPathComponent(
            manifestName
        )
        if manifest != originalManifest
            || !fileManager.fileExists(atPath: manifestURL.path) {
            try saveManifest(manifest, into: destinationDirectory)
        }

        let bundledNames = Set(sourceFiles.map(\.lastPathComponent))
        let userExtensions = try localScripts(
            in: destinationDirectory,
            fileManager: fileManager
        ).filter { !bundledNames.contains($0.lastPathComponent) }
        statuses.append(contentsOf: userExtensions.map {
            DefaultExtensionStatus(
                fileName: $0.lastPathComponent,
                state: .userExtension
            )
        })
        return DefaultExtensionInstallReport(
            statuses: statuses.sorted { $0.fileName < $1.fileName }
        )
    }

    @discardableResult
    public static func resolveConflicts(
        fileNames: Set<String>,
        resolution: DefaultExtensionConflictResolution,
        from sourceDirectory: URL,
        into destinationDirectory: URL,
        fileManager: FileManager = .default,
        now: Date = Date()
    ) throws -> DefaultExtensionInstallReport {
        operationLock.lock()
        defer { operationLock.unlock() }
        guard !fileNames.isEmpty else {
            return try install(
                from: sourceDirectory,
                into: destinationDirectory,
                fileManager: fileManager
            )
        }
        var manifest = try loadManifest(from: destinationDirectory)
        for fileName in fileNames.sorted() {
            guard URL(fileURLWithPath: fileName).lastPathComponent == fileName,
                  fileName.lowercased().hasSuffix(".js") else { continue }
            let source = sourceDirectory.appendingPathComponent(fileName)
            let destination = destinationDirectory.appendingPathComponent(fileName)
            let sourceData = try Data(contentsOf: source)
            let localData = try Data(contentsOf: destination)
            let sourceHash = hash(sourceData)
            switch resolution {
            case .keep:
                var entry = manifest.entries[fileName] ?? Entry()
                entry.keptBundledHash = sourceHash
                manifest.entries[fileName] = entry
            case .update:
                try createBackup(
                    of: destination,
                    data: localData,
                    now: now,
                    fileManager: fileManager
                )
                try sourceData.write(to: destination, options: .atomic)
                manifest.entries[fileName] = Entry(
                    installedBundledHash: sourceHash,
                    keptBundledHash: nil
                )
            }
            try saveManifest(manifest, into: destinationDirectory)
        }
        return try install(
            from: sourceDirectory,
            into: destinationDirectory,
            fileManager: fileManager
        )
    }

    private static func reconcile(
        sourceData: Data,
        sourceHash: String,
        sourceDirectory: URL,
        destination: URL,
        entry: inout Entry?,
        fileManager: FileManager
    ) throws -> DefaultExtensionUpdateState {
        guard fileManager.fileExists(atPath: destination.path) else {
            try sourceData.write(to: destination, options: .atomic)
            entry = Entry(
                installedBundledHash: sourceHash,
                keptBundledHash: nil
            )
            return .bundledCurrent
        }

        let localData = try Data(contentsOf: destination)
        let localHash = hash(localData)
        if localHash == sourceHash {
            entry = Entry(
                installedBundledHash: sourceHash,
                keptBundledHash: nil
            )
            return .bundledCurrent
        }

        if let installedHash = entry?.installedBundledHash {
            if localHash == installedHash {
                try sourceData.write(to: destination, options: .atomic)
                entry = Entry(
                    installedBundledHash: sourceHash,
                    keptBundledHash: nil
                )
                return .bundledCurrent
            }
            if sourceHash == installedHash {
                return .bundledModified
            }
            if entry?.keptBundledHash == sourceHash {
                return .updateKept
            }
            return .updateAvailable
        }

        if try matchesKnownPreviousDefault(
            localData,
            fileName: destination.lastPathComponent,
            sourceDirectory: sourceDirectory,
            fileManager: fileManager
        ) {
            try sourceData.write(to: destination, options: .atomic)
            entry = Entry(
                installedBundledHash: sourceHash,
                keptBundledHash: nil
            )
            return .bundledCurrent
        }
        if entry?.keptBundledHash == sourceHash {
            return .updateKept
        }
        entry = entry ?? Entry()
        return .updateAvailable
    }

    private static func bundledScripts(
        in directory: URL,
        fileManager: FileManager
    ) throws -> [URL] {
        try localScripts(in: directory, fileManager: fileManager)
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func localScripts(
        in directory: URL,
        fileManager: FileManager
    ) throws -> [URL] {
        try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension.lowercased() == "js" }
    }

    private static func matchesKnownPreviousDefault(
        _ localData: Data,
        fileName: String,
        sourceDirectory: URL,
        fileManager: FileManager
    ) throws -> Bool {
        let previous = sourceDirectory.appendingPathComponent(
            fileName + ".previous"
        )
        guard fileManager.fileExists(atPath: previous.path) else {
            return false
        }
        return try Data(contentsOf: previous) == localData
    }

    private static func loadManifest(from directory: URL) throws -> Manifest {
        let file = directory.appendingPathComponent(manifestName)
        guard FileManager.default.fileExists(atPath: file.path) else {
            return Manifest()
        }
        return try JSONDecoder().decode(
            Manifest.self,
            from: Data(contentsOf: file)
        )
    }

    private static func saveManifest(
        _ manifest: Manifest,
        into directory: URL
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(
            to: directory.appendingPathComponent(manifestName),
            options: .atomic
        )
    }

    private static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func createBackup(
        of file: URL,
        data: Data,
        now: Date,
        fileManager: FileManager
    ) throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        let prefix = file.lastPathComponent + ".backup-"
        var backup = file.deletingLastPathComponent().appendingPathComponent(
            prefix + formatter.string(from: now)
        )
        if fileManager.fileExists(atPath: backup.path) {
            backup = file.deletingLastPathComponent().appendingPathComponent(
                prefix + UUID().uuidString
            )
        }
        try data.write(to: backup, options: .atomic)
        try pruneBackups(
            withPrefix: prefix,
            in: file.deletingLastPathComponent(),
            keeping: 5,
            fileManager: fileManager
        )
    }

    private static func pruneBackups(
        withPrefix prefix: String,
        in directory: URL,
        keeping limit: Int,
        fileManager: FileManager
    ) throws {
        let backups = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ).filter { $0.lastPathComponent.hasPrefix(prefix) }
        let dated = try backups.map { file in
            let values = try file.resourceValues(forKeys: [.contentModificationDateKey])
            return (file, values.contentModificationDate ?? .distantPast)
        }.sorted { $0.1 > $1.1 }
        for old in dated.dropFirst(limit) {
            try fileManager.removeItem(at: old.0)
        }
    }

    private static func cleanUpRetiredDefaultsIfNeeded(
        in destinationDirectory: URL,
        fileManager: FileManager
    ) throws {
        let marker = destinationDirectory.appendingPathComponent(markerName)
        guard !fileManager.fileExists(atPath: marker.path) else { return }
        try removeDeprecatedCalendarEventExtension(
            from: destinationDirectory.appendingPathComponent("calendar.js"),
            fileManager: fileManager
        )
        try removeDeprecatedSymbolsExtension(
            from: destinationDirectory.appendingPathComponent("symbols.js"),
            fileManager: fileManager
        )
        try Data().write(to: marker, options: .atomic)
    }

    private static func removeDeprecatedSymbolsExtension(
        from fileURL: URL,
        fileManager: FileManager
    ) throws {
        guard fileManager.fileExists(atPath: fileURL.path),
              let script = try? String(contentsOf: fileURL, encoding: .utf8)
        else { return }
        let previousDefault = """
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
        """
        guard script.trimmingCharacters(in: .whitespacesAndNewlines)
            == previousDefault.trimmingCharacters(in: .whitespacesAndNewlines)
        else { return }
        try fileManager.removeItem(at: fileURL)
    }

    private static func removeDeprecatedCalendarEventExtension(
        from fileURL: URL,
        fileManager: FileManager
    ) throws {
        guard fileManager.fileExists(atPath: fileURL.path),
              let script = try? String(contentsOf: fileURL, encoding: .utf8),
              script.contains("context.input === \"calendar-event\""),
              script.contains("formatCalendarEvent") else { return }
        try fileManager.removeItem(at: fileURL)
    }
}
