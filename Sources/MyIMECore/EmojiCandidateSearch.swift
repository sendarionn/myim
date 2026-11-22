/// The emoji search shared by the emoji panel and the conversion
/// candidates. An emoji is described by normalized terms, such as 猫 and
/// cat; a query matches a term exactly, at its start, or inside it
public enum EmojiCandidateSearch {
    public enum Relevance: Int, Comparable, Sendable {
        case exact
        case prefix
        case contains

        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public struct Entry: Sendable {
        public let emoji: String
        public let terms: [String]

        /// `terms` are normalized with `EmojiSearchMatcher.normalized`
        public init(emoji: String, terms: [String]) {
            self.emoji = emoji
            self.terms = terms
        }
    }

    /// The typed text with its hiragana and katakana, normalized, as the
    /// emoji panel searches with them
    public static func queries(
        for input: String,
        converter: RomajiConverter = RomajiConverter()
    ) -> [String] {
        var values = [input]
        if let hiragana = converter.hiragana(from: input) { values.append(hiragana) }
        if let katakana = converter.katakana(from: input) { values.append(katakana) }
        return unique(values.map(EmojiSearchMatcher.normalized).filter { !$0.isEmpty })
    }

    /// How closely the best of `queries` matches the entry, or nil
    public static func relevance(
        of entry: Entry,
        queries: [String]
    ) -> Relevance? {
        var best: Relevance?
        for query in queries {
            for term in entry.terms {
                let relevance: Relevance?
                if term == query {
                    relevance = .exact
                } else if term.hasPrefix(query) {
                    relevance = .prefix
                } else if term.contains(query) {
                    relevance = .contains
                } else {
                    relevance = nil
                }
                if let relevance, best.map({ relevance < $0 }) ?? true {
                    best = relevance
                    if relevance == .exact { return best }
                }
            }
        }
        return best
    }

    /// Emoji for the conversion candidates: only terms the queries name
    /// whole or begin, closest first and in catalog order otherwise. A
    /// single character only names a term whole, and ASCII shorter than
    /// three letters is not searched, so short input does not fill the
    /// candidates with loosely related emoji
    public static func candidates(
        in entries: [Entry],
        queries: [String],
        excluding existing: Set<String>,
        limit: Int
    ) -> [String] {
        let wholeOnly = queries.filter { query in
            query.count == 1 && !query.allSatisfy(\.isASCII)
        }
        let beginning = queries.filter { query in
            query.allSatisfy(\.isASCII) ? query.count >= 3 : query.count >= 2
        }
        guard !wholeOnly.isEmpty || !beginning.isEmpty else { return [] }
        var ranked: [(relevance: Relevance, index: Int, emoji: String)] = []
        for (index, entry) in entries.enumerated()
        where !existing.contains(entry.emoji) {
            let whole = relevance(of: entry, queries: wholeOnly)
                .flatMap { $0 == .exact ? $0 : nil }
            let begun = relevance(of: entry, queries: beginning)
                .flatMap { $0 <= .prefix ? $0 : nil }
            guard let best = [whole, begun].compactMap({ $0 }).min() else { continue }
            ranked.append((best, index, entry.emoji))
        }
        return unique(
            ranked.sorted { ($0.relevance, $0.index) < ($1.relevance, $1.index) }
                .map(\.emoji)
        ).prefix(limit).map { $0 }
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
