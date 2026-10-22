import Testing
@testable import MyIMECore

@Suite
struct FuzzyQueryResolverTests {
    @Test(arguments: [
        "a=to", "a_to", "a+to", "a)to", "ko=hi-", "de=tabe=su", "A=to"
    ])
    func searchesTheWholeInputForLongVowelKeyTypos(input: String) {
        #expect(FuzzyQueryResolver.resolve(
            input: input,
            conversionReading: ConversionReadingResolver.resolve(input)
        ) == input)
    }

    @Test(arguments: [
        "a=b", "foo=bar", "1+2=", "3.14", "14:30", "example.com",
        "user@example.com", "a/to", "a=", "de=", "k=to", "a==to", "kana"
    ])
    func keepsTheReadingForOtherInput(input: String) {
        let reading = ConversionReadingResolver.resolve(input)

        #expect(FuzzyQueryResolver.resolve(
            input: input,
            conversionReading: reading
        ) == reading)
    }

    @Test
    func correctsTheSymbolToTheLongVowelMark() {
        #expect(RomajiKeyboardTypoGenerator.corrections(for: "a=to")
            .contains("a-to"))
        #expect(RomajiKeyboardTypoGenerator.corrections(for: "a_to")
            .contains("a-to"))
        #expect(!RomajiKeyboardTypoGenerator.corrections(for: "a/to")
            .contains("a-to"))
    }
}
