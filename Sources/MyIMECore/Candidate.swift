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
    case adjectiveInflection
    case particleComposition
    case englishCompletion
    case uppercase
    case translation
    case fuzzyCandidate
    case nextInput
    case specialConversion
    /// An emoji found by the emoji search for the typed input
    case emoji
    /// The whole composition converted by the experimental live conversion
    case liveConversion
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
    public let inflectionBase: InflectionBaseIdentity?
    /// Words the candidate is made from other than an inflection's base,
    /// as 私 of the composition 私は
    public let baseWords: [CandidateBaseWord]

    public init(
        source: CandidateSourceKind,
        reading: String? = nil,
        isLearnable: Bool = false,
        attributes: Attributes = [],
        inflectionBase: InflectionBaseIdentity? = nil,
        baseWords: [CandidateBaseWord] = []
    ) {
        self.source = source
        self.reading = reading
        self.isLearnable = isLearnable
        self.attributes = attributes
        self.inflectionBase = inflectionBase
        self.baseWords = baseWords
    }
}

public struct Candidate: Equatable, Sendable {
    public static let dynamicPreferenceIDMetadataKey = "dynamicPreferenceID"

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
        inflectionBase: InflectionBaseIdentity? = nil,
        baseWords: [CandidateBaseWord] = [],
        priority: Int? = nil,
        contextualMetadata: [String: String] = [:]
    ) {
        self.storageText = storageText
        origins = [CandidateOrigin(
            source: source,
            reading: reading,
            isLearnable: isLearnable,
            attributes: attributes,
            inflectionBase: inflectionBase,
            baseWords: baseWords
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

    /// Dynamic date/time values are regenerated for the current clock and
    /// must not become historical candidates on their own
    public var allowsSelectionHistory: Bool {
        origins.contains { $0.source != .dateTime }
    }

    public var dynamicPreferenceID: String? {
        contextualMetadata[Self.dynamicPreferenceIDMetadataKey]
    }

    public var selectionHistoryValue: String? {
        allowsSelectionHistory ? storageText : dynamicPreferenceID
    }

    public var uniqueInflectionBase: InflectionBaseIdentity? {
        let bases = Set(origins.compactMap(\.inflectionBase))
        return bases.count == 1 ? bases.first : nil
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
