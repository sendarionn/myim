import Foundation

public enum EmojiSearchMatcher {
    public static func matches(query: String, terms: [String]) -> Bool {
        let query = normalized(query)
        guard !query.isEmpty else { return true }
        return terms.contains { normalized($0).contains(query) }
    }

    private static func normalized(_ value: String) -> String {
        value.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "ja_JP")
        ).replacingOccurrences(of: " ", with: "")
    }
}
