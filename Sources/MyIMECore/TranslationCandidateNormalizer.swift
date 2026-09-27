import Foundation

public enum TranslationCandidateNormalizer {
    public static func wordCandidates(from translation: String) -> [String] {
        let separators = CharacterSet.newlines.union(
            CharacterSet(charactersIn: "/／;；")
        )
        var seen = Set<String>()
        return translation
            .components(separatedBy: separators)
            .compactMap { wordCandidate(from: $0) }
            .filter { seen.insert($0).inserted }
    }

    public static func wordCandidate(from translation: String) -> String? {
        var value = translation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        let lowercased = value.lowercased()
        for article in ["a ", "an ", "the "] where lowercased.hasPrefix(article) {
            value.removeFirst(article.count)
            break
        }
        if value.hasSuffix("."), !value.hasSuffix("...") {
            value.removeLast()
        }
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
