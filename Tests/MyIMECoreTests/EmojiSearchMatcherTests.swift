import Testing
@testable import MyIMECore

struct EmojiSearchMatcherTests {
    @Test func searchesJapaneseTerms() {
        #expect(EmojiSearchMatcher.matches(
            query: "笑顔",
            terms: ["にっこり笑う", "笑顔", "顔"]
        ))
    }

    @Test func searchesEnglishTermsIgnoringCaseAndSpaces() {
        #expect(EmojiSearchMatcher.matches(
            query: "GRINNINGFACE",
            terms: ["grinning face", "smile"]
        ))
    }

    @Test func rejectsUnrelatedTerms() {
        #expect(!EmojiSearchMatcher.matches(
            query: "cat",
            terms: ["dog", "puppy"]
        ))
    }

    @Test func matchesKatakanaGeneratedFromRomaji() {
        #expect(EmojiSearchMatcher.matches(
            query: "ネコ",
            terms: ["ネコ", "猫", "ペット"]
        ))
    }
}
