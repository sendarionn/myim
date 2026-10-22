/// Punctuation typed right after text is converted after the text, so
/// `watashiha,` becomes 私は and then 、 without retyping the comma
public struct TrailingPunctuationSplit: Equatable, Sendable {
    public static let characters: Set<Character> = [",", ".", "!", "?"]

    public let body: String
    public let punctuation: String

    public init(body: String, punctuation: String) {
        self.body = body
        self.punctuation = punctuation
    }

    /// Splits only punctuation at the end that follows a word, so
    /// `example.com`, `3.14` and `hello,world` stay whole
    public static func split(_ input: String) -> Self? {
        let punctuation = String(
            input.reversed().prefix { characters.contains($0) }.reversed()
        )
        guard !punctuation.isEmpty else { return nil }
        let body = String(input.dropLast(punctuation.count))
        guard let last = body.last,
              (last.isASCII && last.isLetter) || last == "-",
              body.contains(where: { $0.isASCII && $0.isLetter }) else {
            return nil
        }
        return Self(body: body, punctuation: punctuation)
    }

    /// Punctuation left after the text was committed converts as one group
    /// when the group has symbol candidates, and otherwise one character
    /// at a time in the order typed
    public static func splitCarried(
        _ input: String,
        convertsAsGroup: Bool
    ) -> Self? {
        guard input.count > 1,
              input.allSatisfy(characters.contains),
              !convertsAsGroup else {
            return nil
        }
        return Self(
            body: String(input.prefix(1)),
            punctuation: String(input.dropFirst())
        )
    }
}
