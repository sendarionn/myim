import Foundation
import MyIMECore

struct CosenseCredentialStore {
    func load(for project: String) -> CosenseCredential? {
        let credentials = loadCredentials()
        if let value = credentials.serviceAccounts[project.lowercased()] {
            return CosenseCredential(kind: .serviceAccount, value: value)
        }
        if let value = credentials.personalAccessToken {
            return CosenseCredential(kind: .personalAccessToken, value: value)
        }
        return nil
    }

    func save(_ credential: CosenseCredential, project: String) throws {
        var credentials = loadCredentials()
        switch credential.kind {
        case .personalAccessToken:
            credentials.personalAccessToken = credential.value
        case .serviceAccount:
            credentials.serviceAccounts[project.lowercased()] =
                credential.value
        }
        try saveCredentials(credentials)
    }

    func delete(kind: CosenseCredential.Kind, project: String) throws {
        var credentials = loadCredentials()
        switch kind {
        case .personalAccessToken:
            credentials.personalAccessToken = nil
        case .serviceAccount:
            credentials.serviceAccounts.removeValue(
                forKey: project.lowercased()
            )
        }
        try saveCredentials(credentials)
    }

    private func loadCredentials() -> StoredCredentials {
        guard
            let data = try? Data(contentsOf: credentialsURL),
            let credentials = try? JSONDecoder().decode(
                StoredCredentials.self,
                from: data
            )
        else {
            return StoredCredentials()
        }
        return credentials
    }

    private func saveCredentials(
        _ credentials: StoredCredentials
    ) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: credentialsDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: credentialsDirectory.path
        )

        let data = try JSONEncoder().encode(credentials)
        try data.write(to: credentialsURL, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: credentialsURL.path
        )
    }

    private var credentialsDirectory: URL {
        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        .appendingPathComponent("myim/credentials", isDirectory: true)
    }

    private var credentialsURL: URL {
        credentialsDirectory.appendingPathComponent("cosense.json")
    }
}

private struct StoredCredentials: Codable {
    var personalAccessToken: String?
    var serviceAccounts: [String: String] = [:]
}
