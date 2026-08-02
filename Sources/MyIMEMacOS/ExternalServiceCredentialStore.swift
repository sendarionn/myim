import Foundation

struct ExternalServiceCredentialStore {
    func loadAzureTranslatorKey() -> String {
        (try? String(contentsOf: keyURL, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func saveAzureTranslatorKey(_ key: String) throws {
        let manager = FileManager.default
        try manager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directoryURL.path)
        try Data(key.utf8).write(to: keyURL, options: .atomic)
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyURL.path)
    }

    private var directoryURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("myim/credentials", isDirectory: true)
    }

    private var keyURL: URL {
        directoryURL.appendingPathComponent("azure-translator-key.txt")
    }
}
