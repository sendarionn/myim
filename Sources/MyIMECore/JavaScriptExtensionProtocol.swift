import Foundation

public struct JavaScriptExtensionRequest: Codable, Sendable {
    public let id: UUID
    public let input: String
    public let timestamp: String
    public let timeZone: String
    public let extensionDirectories: [String]
    public let disabledFileNames: [String]
    public let settings: [String: [String]]

    public init(
        id: UUID = UUID(),
        input: String,
        timestamp: String,
        timeZone: String,
        extensionDirectories: [String],
        disabledFileNames: [String] = [],
        settings: [String: [String]] = [:]
    ) {
        self.id = id
        self.input = input
        self.timestamp = timestamp
        self.timeZone = timeZone
        self.extensionDirectories = extensionDirectories
        self.disabledFileNames = disabledFileNames
        self.settings = settings
    }
}

public struct JavaScriptExtensionStatus: Codable, Equatable, Sendable {
    public enum State: String, Codable, Sendable {
        case ready
        case disabled
        case error
    }

    public let fileName: String
    public let state: State
    public let message: String?

    public init(fileName: String, state: State, message: String? = nil) {
        self.fileName = fileName
        self.state = state
        self.message = message
    }
}

public struct JavaScriptExtensionResponse: Codable, Sendable {
    public let id: UUID
    public let candidates: [String]
    public let errors: [String]
    public let statuses: [JavaScriptExtensionStatus]

    public init(
        id: UUID,
        candidates: [String],
        errors: [String] = [],
        statuses: [JavaScriptExtensionStatus] = []
    ) {
        self.id = id
        self.candidates = candidates
        self.errors = errors
        self.statuses = statuses
    }
}
