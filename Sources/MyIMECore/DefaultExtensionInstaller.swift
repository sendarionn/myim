import Foundation

public enum DefaultExtensionInstaller {
    public static let markerName = ".myim-default-extensions-installed-v21"

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
        try removeDeprecatedCalendarEventExtension(
            from: destinationDirectory.appendingPathComponent("calendar.js"),
            fileManager: fileManager
        )
        try addUnprefixedBinaryCandidate(
            to: destinationDirectory.appendingPathComponent("numeric-tools.js"),
            fileManager: fileManager
        )

        try Data().write(to: marker, options: .atomic)
    }

    private static func addUnprefixedBinaryCandidate(
        to fileURL: URL,
        fileManager: FileManager
    ) throws {
        guard fileManager.fileExists(atPath: fileURL.path),
              var script = try? String(contentsOf: fileURL, encoding: .utf8),
              !script.contains("return [sign + digits]")
        else { return }
        let oldImplementations = ["""
          const sign = value < 0 ? "-" : ""
          return [sign + "0b" + Math.abs(value).toString(2)]
        """, """
          const sign = value < 0 ? "-" : ""
          const unsigned = "0b" + Math.abs(value).toString(2)
          return sign ? [sign + unsigned, unsigned] : [unsigned]
        """, """
          const sign = value < 0 ? "-" : ""
          const digits = Math.abs(value).toString(2)
          return [sign + "0b" + digits, sign + digits]
        """]
        let newImplementation = """
          const sign = value < 0 ? "-" : ""
          const digits = Math.abs(value).toString(2)
          return [sign + digits]
        """
        guard let oldImplementation = oldImplementations.first(where: script.contains)
        else { return }
        script = script.replacingOccurrences(of: oldImplementation, with: newImplementation)
        try script.write(to: fileURL, atomically: true, encoding: .utf8)
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
