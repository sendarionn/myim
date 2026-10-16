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

    /// Where the innermost open bracket is in its single offer of the
    /// closing bracket
    private enum Phase: Equatable, Sendable {
        case inactive
        /// Opened, waiting for the first text committed or pasted after it
        case awaitingFirstCommit
        /// The first text after the opening was just committed
        case offering
        /// Offered or cancelled; the same opening is not offered again
        case finished
    }

    private var pendingClosings: [Character] = []
    private var phase = Phase.inactive

    public init() {}

    /// The closing bracket offered right after the first text following its
    /// opening, and only until the next input starts
    public var candidate: String? {
        guard phase == .offering else { return nil }
        return pendingClosings.last.map(String.init)
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

    /// Follows text committed or pasted at the insertion point
    public mutating func consume(_ text: String) {
        // The text after the offered closing ends the offer
        endOffering()
        for character in text {
            if let closing = Self.pairs[character] {
                pendingClosings.append(closing)
                phase = .awaitingFirstCommit
            } else if let index = pendingClosings.lastIndex(where: {
                Self.kind(of: $0) == Self.kind(of: character)
            }) {
                // Brackets opened inside and left unclosed end with it
                pendingClosings.removeSubrange(index...)
                phase = .finished
            } else if phase == .awaitingFirstCommit,
                      !character.isWhitespace {
                phase = .offering
            }
        }
    }

    /// Ends the offer when the next input starts or its panel closes
    public mutating func endOffering() {
        if phase == .offering {
            phase = .finished
        }
    }

    /// Cancels the offer when the insertion point moves or the text it
    /// was opened in is left
    public mutating func reset() {
        pendingClosings = []
        phase = .inactive
    }

    private static func kind(of closing: Character) -> Character {
        closingKinds[closing] ?? closing
    }
}
