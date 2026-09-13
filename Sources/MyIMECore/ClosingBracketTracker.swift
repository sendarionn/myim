public struct ClosingBracketTracker: Equatable, Sendable {
    private static let pairs: [Character: Character] = [
        "(": ")", "（": "）", "[": "]", "［": "］", "{": "}",
        "「": "」", "『": "』", "【": "】", "〈": "〉", "《": "》",
        "〔": "〕", "〖": "〗", "〘": "〙", "〚": "〛",
        "“": "”", "‘": "’"
    ]

    private var pendingClosings: [Character] = []

    public init() {}

    public var candidate: String? {
        pendingClosings.last.map(String.init)
    }

    public func shouldRecordAsNextInput(_ value: String) -> Bool {
        value != candidate
    }

    public mutating func consume(_ text: String) {
        for character in text {
            if let closing = Self.pairs[character] {
                pendingClosings.append(closing)
            } else if character == pendingClosings.last {
                pendingClosings.removeLast()
            }
        }
    }
}
