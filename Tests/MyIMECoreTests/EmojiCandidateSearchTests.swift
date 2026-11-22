import Testing
@testable import MyIMECore

@Suite
struct EmojiCandidateSearchTests {
    private let entries = [
        EmojiCandidateSearch.Entry(emoji: "😺", terms: ["にっこり笑う猫", "猫", "笑顔", "grinning cat", "cat"]),
        EmojiCandidateSearch.Entry(emoji: "🐱", terms: ["猫の顔", "猫", "cat face", "cat"]),
        EmojiCandidateSearch.Entry(emoji: "🐈", terms: ["猫", "cat"]),
        EmojiCandidateSearch.Entry(emoji: "📚", terms: ["本", "books", "catalog"]),
        EmojiCandidateSearch.Entry(emoji: "🍣", terms: ["寿司", "sushi"])
    ]

    @Test
    func wordsOfTheConversionNameTheEmoji() {
        let found = EmojiCandidateSearch.candidates(
            in: entries,
            queries: ["猫"],
            excluding: [],
            limit: 4
        )

        #expect(found == ["😺", "🐱", "🐈"])
    }

    /// A term named whole comes before one that only begins with the query
    @Test
    func wholeTermsComeFirst() {
        let found = EmojiCandidateSearch.candidates(
            in: entries,
            queries: ["cat"],
            excluding: [],
            limit: 10
        )

        #expect(found.first == "😺")
        #expect(found.last == "📚")
    }

    @Test
    func emojiAlreadyListedAndShortInputAreLeftOut() {
        let found = EmojiCandidateSearch.candidates(
            in: entries,
            queries: ["猫"],
            excluding: ["😺"],
            limit: 1
        )
        let short = EmojiCandidateSearch.candidates(
            in: entries,
            queries: ["ca", "の"],
            excluding: [],
            limit: 4
        )

        #expect(found == ["🐱"])
        #expect(short.isEmpty)
    }

    @Test
    func panelMatchesAnyPartOfATerm() {
        let relevance = EmojiCandidateSearch.relevance(
            of: entries[0],
            queries: ["っこり"]
        )

        #expect(relevance == .contains)
    }

    @Test
    func typedRomajiIsSearchedWithItsKana() {
        #expect(EmojiCandidateSearch.queries(for: "sushi") == ["sushi", "すし", "スシ"])
    }

    /// The index finds what reading every entry finds
    @Test
    func indexFindsWhatEveryEntryNames() {
        let index = EmojiCandidateSearch.Index(entries: entries)
        for queries in [["猫"], ["cat"], ["neko", "ねこ", "ネコ", "猫"], ["本", "boo"], ["すし", "寿"], ["の", "ca"]] {
            let expected = entries.enumerated()
                .compactMap { offset, entry -> (EmojiCandidateSearch.Relevance, Int, String)? in
                    let found = queries.compactMap { query -> EmojiCandidateSearch.Relevance? in
                        let ascii = query.allSatisfy(\.isASCII)
                        guard let relevance = EmojiCandidateSearch.relevance(of: entry, queries: [query]) else { return nil }
                        if query.count == 1 && !ascii { return relevance == .exact ? relevance : nil }
                        guard ascii ? query.count >= 3 : query.count >= 2 else { return nil }
                        return relevance <= .prefix ? relevance : nil
                    }.min()
                    return found.map { ($0, offset, entry.emoji) }
                }
                .sorted { ($0.0, $0.1) < ($1.0, $1.1) }
                .map(\.2)
            #expect(
                EmojiCandidateSearch.candidates(in: index, queries: queries, excluding: [], limit: 10) == expected,
                "\(queries)"
            )
        }
    }
}
