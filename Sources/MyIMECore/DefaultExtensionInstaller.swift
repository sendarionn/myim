import Foundation

public enum DefaultExtensionInstaller {
    public static let markerName = ".myim-default-extensions-installed-v7"

    public static func installIfNeeded(
        from sourceDirectory: URL,
        into destinationDirectory: URL,
        fileManager: FileManager = .default
    ) throws {
        try fileManager.createDirectory(
            at: destinationDirectory,
            withIntermediateDirectories: true
        )
        let marker = destinationDirectory.appendingPathComponent(markerName)
        guard !fileManager.fileExists(atPath: marker.path) else { return }

        let sourceFiles = try fileManager.contentsOfDirectory(
            at: sourceDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension.lowercased() == "js" }

        for source in sourceFiles {
            let destination = destinationDirectory
                .appendingPathComponent(source.lastPathComponent)
            if fileManager.fileExists(atPath: destination.path) {
                let previous = sourceDirectory.appendingPathComponent(
                    source.lastPathComponent + ".previous"
                )
                if fileManager.fileExists(atPath: previous.path),
                   try Data(contentsOf: destination) == Data(contentsOf: previous) {
                    try fileManager.removeItem(at: destination)
                    try fileManager.copyItem(at: source, to: destination)
                }
                continue
            }
            try fileManager.copyItem(at: source, to: destination)
        }

        try removeDeprecatedDateTimeReadings(
            from: destinationDirectory.appendingPathComponent("datetime.js"),
            fileManager: fileManager
        )
        try addWeekdayTokenSupport(
            to: destinationDirectory.appendingPathComponent("datetime.js"),
            fileManager: fileManager
        )

        try Data().write(to: marker, options: .atomic)
    }

    private static func addWeekdayTokenSupport(
        to fileURL: URL,
        fileManager: FileManager
    ) throws {
        guard fileManager.fileExists(atPath: fileURL.path),
              var script = try? String(contentsOf: fileURL, encoding: .utf8),
              !script.contains("E: weekdays[date.getDay()]") else { return }
        let functionHeader = "function format(date, formats) {\n"
        guard script.contains(functionHeader),
              script.contains("  const values = {\n") else { return }
        script = script.replacingOccurrences(
            of: functionHeader,
            with: functionHeader
                + "  const weekdays = [\"日\", \"月\", \"火\", \"水\", \"木\", \"金\", \"土\"]\n"
        )
        script = script.replacingOccurrences(
            of: "  const values = {\n",
            with: "  const values = {\n    E: weekdays[date.getDay()],\n"
        )
        script = script.replacingOccurrences(
            of: "\"M\", \"D\", \"H\", \"m\", \"s\"]",
            with: "\"M\", \"D\", \"H\", \"m\", \"s\", \"E\"]"
        )
        try script.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private static func removeDeprecatedDateTimeReadings(
        from fileURL: URL,
        fileManager: FileManager
    ) throws {
        guard fileManager.fileExists(atPath: fileURL.path),
              var script = try? String(contentsOf: fileURL, encoding: .utf8),
              script.contains("dateTimeReadings") else { return }
        let patterns = [
            #"(?ms)^  const dateTimeFormats = \[.*?^  \]\n"#,
            #"(?m)^  const dateTimeReadings = .*\n"#,
            #"(?ms)^  if \(dateTimeReadings\.indexOf\(input\) >= 0\) \{\n    return format\(now, dateTimeFormats\)\n  \}\n"#
        ]
        for pattern in patterns {
            script = script.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }
        try script.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
