import Foundation

public enum DefaultExtensionInstaller {
    public static let markerName = ".myim-default-extensions-installed-v5"

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

        try Data().write(to: marker, options: .atomic)
    }
}
