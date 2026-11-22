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

    /// The terms of the entries sorted for lookup, so the conversion
    /// candidates, searched on every key, need not read every entry
    public struct Index: Sendable {
        fileprivate let emojis: [String]
        /// Each term with the entry it describes, by its precomposed UTF-8
        fileprivate let terms: [(key: [UInt8], term: String, entry: Int)]

        public init(entries: [Entry]) {
            emojis = entries.map(\.emoji)
            terms = entries.enumerated()
                .flatMap { index, entry in
                    entry.terms.map { (Index.key($0), $0, index) }
                }
                .sorted { $0.key.lexicographicallyPrecedes($1.key) }
        }

        fileprivate static func key(_ value: String) -> [UInt8] {
            Array(value.precomposedStringWithCanonicalMapping.utf8)
        }

        /// The entries with a term the query names whole, or also begins
        fileprivate func matches(
            _ query: String,
            includingPrefixes: Bool,
            into best: inout [Int: Relevance]
        ) {
            let key = Index.key(query)
            var low = 0
            var high = terms.count
            while low < high {
                let middle = (low + high) / 2
                if terms[middle].key.lexicographicallyPrecedes(key) {
                    low = middle + 1
                } else {
                    high = middle
                }
            }
            var position = low
            while position < terms.count, terms[position].key.starts(with: key) {
                let item = terms[position]
                position += 1
                let relevance: Relevance
                if item.term == query {
                    relevance = .exact
                } else if includingPrefixes, item.term.hasPrefix(query) {
                    relevance = .prefix
                } else {
                    continue
                }
                if best[item.entry].map({ relevance < $0 }) ?? true {
                    best[item.entry] = relevance
                }
            }
        }
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
        candidates(
            in: Index(entries: entries),
            queries: queries,
            excluding: existing,
            limit: limit
        )
    }

    public static func candidates(
        in index: Index,
        queries: [String],
        excluding existing: Set<String>,
        limit: Int
    ) -> [String] {
        var best: [Int: Relevance] = [:]
        for query in unique(queries) {
            if query.allSatisfy(\.isASCII) ? query.count >= 3 : query.count >= 2 {
                index.matches(query, includingPrefixes: true, into: &best)
            } else if query.count == 1, !query.allSatisfy(\.isASCII) {
                index.matches(query, includingPrefixes: false, into: &best)
            }
        }
        return unique(
            best.filter { !existing.contains(index.emojis[$0.key]) }
                .sorted { ($0.value, $0.key) < ($1.value, $1.key) }
                .map { index.emojis[$0.key] }
        ).prefix(limit).map { $0 }
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
