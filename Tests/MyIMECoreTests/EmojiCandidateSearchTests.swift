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
}
