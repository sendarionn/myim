import Foundation

enum BuildIdentityReporter {
    private static let runtimeStatusFilename = "runtime-status.json"
    private static let inputSessionDirectoryName = "input-sessions"

    static func printCurrent() throws {
        let identity = currentIdentity()
        for key in [
            "bundle-path",
            "executable-path",
            "version",
            "build",
            "git-commit",
            "git-dirty",
            "build-timestamp"
        ] {
            print("\(key)=\(identity[key] ?? "unknown")")
        }
    }

    static func writeRuntimeStatus() {
        var identity = currentIdentity()
        identity["pid"] = String(ProcessInfo.processInfo.processIdentifier)
        identity["started-at"] = ISO8601DateFormatter().string(from: Date())

        do {
            let url = try runtimeStatusURL()
            let data = try JSONSerialization.data(
                withJSONObject: identity,
                options: [.prettyPrinted, .sortedKeys]
            )
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog(
                "myim: runtime build identity write failed error=%@",
                error.localizedDescription
            )
        }
    }

    static func writeInputSessionStatus(
        clientBundleIdentifier: String,
        controllerID: String,
        sessionGeneration: UInt,
        activatedAt: Date = Date()
    ) {
        var identity = currentIdentity()
        identity["client-bundle-id"] = clientBundleIdentifier
        identity["pid"] = String(ProcessInfo.processInfo.processIdentifier)
        identity["controller-id"] = controllerID
        identity["session-generation"] = String(sessionGeneration)
        identity["activated-at"] = ISO8601DateFormatter().string(
            from: activatedAt
        )

        do {
            let directory = try inputSessionStatusDirectoryURL()
            let filename = safeFilename(for: clientBundleIdentifier) + ".json"
            let url = directory.appendingPathComponent(filename)
            let data = try JSONSerialization.data(
                withJSONObject: identity,
                options: [.prettyPrinted, .sortedKeys]
            )
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog(
                "myim: input session identity write failed error=%@",
                error.localizedDescription
            )
        }
    }

    private static func currentIdentity() -> [String: String] {
        let info = Bundle.main.infoDictionary ?? [:]
        return [
            "bundle-path": Bundle.main.bundleURL.path,
            "executable-path": Bundle.main.executableURL?.path ?? "unknown",
            "version": info["CFBundleShortVersionString"] as? String
                ?? "unknown",
            "build": info["CFBundleVersion"] as? String ?? "unknown",
            "git-commit": info["MyIMGitCommit"] as? String ?? "unknown",
            "git-dirty": String(info["MyIMGitDirty"] as? Bool ?? false),
            "build-timestamp": info["MyIMBuildTimestamp"] as? String
                ?? "unknown"
        ]
    }

    private static func runtimeStatusURL() throws -> URL {
        try statusDirectoryURL().appendingPathComponent(
            runtimeStatusFilename
        )
    }

    private static func inputSessionStatusDirectoryURL() throws -> URL {
        let directory = try statusDirectoryURL().appendingPathComponent(
            inputSessionDirectoryName,
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private static func statusDirectoryURL() throws -> URL {
        let caches = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = caches.appendingPathComponent(
            "myim",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private static func safeFilename(for bundleIdentifier: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(
            CharacterSet(charactersIn: "._-")
        )
        return bundleIdentifier.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? String(scalar) : "_"
        }.joined()
    }
}
