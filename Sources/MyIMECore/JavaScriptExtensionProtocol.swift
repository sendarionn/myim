import Foundation

public struct JavaScriptExtensionRequest: Codable, Sendable {
    public let id: UUID
    public let input: String
    public let timestamp: String
    public let timeZone: String
    public let extensionDirectories: [String]
    public let settings: [String: [String]]

    public init(
        id: UUID = UUID(),
        input: String,
        timestamp: String,
        timeZone: String,
        extensionDirectories: [String],
        settings: [String: [String]] = [:]
    ) {
        self.id = id
        self.input = input
        self.timestamp = timestamp
        self.timeZone = timeZone
        self.extensionDirectories = extensionDirectories
        self.settings = settings
    }
}

public struct JavaScriptExtensionResponse: Codable, Sendable {
    public let id: UUID
    public let candidates: [String]
    public let errors: [String]

    public init(id: UUID, candidates: [String], errors: [String] = []) {
        self.id = id
        self.candidates = candidates
        self.errors = errors
    }
}
