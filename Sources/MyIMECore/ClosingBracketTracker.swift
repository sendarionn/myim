public struct ClosingBracketTracker: Equatable, Sendable {
    private static let pairs: [Character: Character] = [
        "(": ")", "（": "）", "[": "]", "［": "］", "{": "}",
        "「": "」", "『": "』", "【": "】", "〈": "〉", "《": "》",
        "〔": "〕", "〖": "〗", "〘": "〙", "〚": "〛",
        "“": "”", "‘": "’"
    ]

    /// Full-width and ASCII forms close each other, since either may be
    /// chosen from the candidates for the opening and the closing
    private static let closingKinds: [Character: Character] = [
        "）": ")", "］": "]", "｝": "}"
    ]

    private static let closings = Set(pairs.values)
        .union(closingKinds.keys)

    private var pendingClosings: [Character] = []

    public init() {}

    public var candidate: String? {
        pendingClosings.last.map(String.init)
    }

    /// A closing bracket alone belongs to its opening rather than to the
    /// text before it, so it is never learned as a following word
    public func shouldRecordAsNextInput(_ value: String) -> Bool {
        value != candidate && !Self.isClosingBracket(value)
    }

    /// Learned and dictionary continuations starting with a closing bracket
    /// are left to the structural candidate, which knows whether a bracket
    /// is open
    public static func startsWithClosingBracket(_ value: String) -> Bool {
        value.first.map(closings.contains) ?? false
    }

    public static func isClosingBracket(_ value: String) -> Bool {
        value.count == 1 && startsWithClosingBracket(value)
    }

    public func shouldBypassCandidateSuppression(_ value: String) -> Bool {
        value == candidate
    }

    public func shouldConsumeTypedClosing(
        _ typedText: String,
        selectedCandidate: String
    ) -> Bool {
        guard let candidate else { return false }
        return selectedCandidate == candidate && typedText == candidate
    }

    public func shouldRecordCommittedInput(
        _ value: String,
        requested: Bool
    ) -> Bool {
        requested && shouldRecordAsNextInput(value)
    }

    public func shouldPreserveCandidatesDuringEmptySystemCommit(
        hasCandidates: Bool
    ) -> Bool {
        candidate != nil && hasCandidates
    }

    public mutating func consume(_ text: String) {
        for character in text {
            if let closing = Self.pairs[character] {
                pendingClosings.append(closing)
            } else if let index = pendingClosings.lastIndex(where: {
                Self.kind(of: $0) == Self.kind(of: character)
            }) {
                // Brackets opened inside and left unclosed end with it
                pendingClosings.removeSubrange(index...)
            }
        }
    }

    /// Forgets open brackets when the text they were opened in is left
    public mutating func reset() {
        pendingClosings = []
    }

    private static func kind(of closing: Character) -> Character {
        closingKinds[closing] ?? closing
    }
}
