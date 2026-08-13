import Testing
@testable import MyIMECore

struct TranslationCandidateNormalizerTests {
    @Test
    func removesLeadingEnglishArticles() {
        #expect(TranslationCandidateNormalizer.wordCandidate(from: "a book") == "book")
        #expect(TranslationCandidateNormalizer.wordCandidate(from: "An apple") == "apple")
        #expect(TranslationCandidateNormalizer.wordCandidate(from: "The cause") == "cause")
    }

    @Test
    func removesSentencePeriodFromWordCandidate() {
        #expect(TranslationCandidateNormalizer.wordCandidate(from: "translation.") == "translation")
        #expect(TranslationCandidateNormalizer.wordCandidate(from: "...") == "...")
    }

    @Test
    func preservesWordsWithoutArticles() {
        #expect(TranslationCandidateNormalizer.wordCandidate(from: "return") == "return")
        #expect(TranslationCandidateNormalizer.wordCandidate(from: "to think") == "to think")
    }
}
