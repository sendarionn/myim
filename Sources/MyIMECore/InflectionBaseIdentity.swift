public struct InflectionBaseIdentity: Codable, Equatable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case verb
        case adjective
    }

    public let kind: Kind
    public let reading: String
    public let surface: String
    public let inflectionType: String

    public init(
        kind: Kind,
        reading: String,
        surface: String,
        inflectionType: String
    ) {
        self.kind = kind
        self.reading = reading
        self.surface = surface
        self.inflectionType = inflectionType
    }

    public var historyKey: String {
        [kind.rawValue, reading, surface, inflectionType]
            .joined(separator: "\u{1f}")
    }
}

public struct GeneratedInflectionCandidate: Equatable, Sendable {
    public let text: String
    public let bases: [InflectionBaseIdentity]

    public init(text: String, bases: [InflectionBaseIdentity] = []) {
        self.text = text
        self.bases = bases
    }
}
