public enum CandidateSourceKind: String, CaseIterable, Sendable {
    case unspecified
    case automaticKana
    case userDictionary
    case importedDictionary
    case selectionHistory
    case dateTime
    case numericPrefix
    case javaScriptExtension
    case symbolDictionary
    case basicDictionary
    case systemDictionary
    case verbInflection
    case particleComposition
    case englishCompletion
    case externalSuggestion
    case wikipedia
    case googleJapaneseInput
    case uppercase
    case translation
    case fuzzySuggestion
    case nextInput
    case specialConversion
}

public struct CandidateOrigin: Equatable, Sendable {
    public struct Attributes: OptionSet, Equatable, Sendable {
        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        public static let generated = Self(rawValue: 1 << 0)
        public static let preservesLongVowelNotation = Self(rawValue: 1 << 1)
    }

    public let source: CandidateSourceKind
    public let reading: String?
    public let isLearnable: Bool
    public let attributes: Attributes

    public init(
        source: CandidateSourceKind,
        reading: String? = nil,
        isLearnable: Bool = false,
        attributes: Attributes = []
    ) {
        self.source = source
        self.reading = reading
        self.isLearnable = isLearnable
        self.attributes = attributes
    }
}

public struct Candidate: Equatable, Sendable {
    public let storageText: String
    public private(set) var origins: [CandidateOrigin]
    public let priority: Int?
    public let contextualMetadata: [String: String]

    public init(
        storageText: String,
        source: CandidateSourceKind = .unspecified,
        reading: String? = nil,
        isLearnable: Bool = false,
        attributes: CandidateOrigin.Attributes = [],
        priority: Int? = nil,
        contextualMetadata: [String: String] = [:]
    ) {
        self.storageText = storageText
        origins = [CandidateOrigin(
            source: source,
            reading: reading,
            isLearnable: isLearnable,
            attributes: attributes
        )]
        self.priority = priority
        self.contextualMetadata = contextualMetadata
    }

    public var displayText: String {
        DictionaryCandidateRepresentation.display(from: storageText)
    }

    public var commitText: String {
        DictionaryCandidateRepresentation.value(from: storageText)
    }

    public var hasDistinctCommitText: Bool {
        displayText != commitText
    }

    public var primarySource: CandidateSourceKind {
        origins.first?.source ?? .unspecified
    }

    public var sources: Set<CandidateSourceKind> {
        Set(origins.map(\.source))
    }

    public var isLearnable: Bool {
        origins.contains(where: \.isLearnable)
    }

    public func hasSource(_ source: CandidateSourceKind) -> Bool {
        origins.contains { $0.source == source }
    }

    public func hasAttribute(
        _ attribute: CandidateOrigin.Attributes
    ) -> Bool {
        origins.contains { $0.attributes.contains(attribute) }
    }

    public func mergingOrigins(from other: Candidate) -> Candidate {
        guard storageText == other.storageText else { return self }
        var result = self
        for origin in other.origins where !result.origins.contains(origin) {
            result.origins.append(origin)
        }
        return result
    }
}
