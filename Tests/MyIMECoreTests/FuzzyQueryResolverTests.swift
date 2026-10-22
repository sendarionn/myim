import Testing
@testable import MyIMECore

@Suite
struct FuzzyQueryResolverTests {
    @Test(arguments: [
        "a=to", "a_to", "a+to", "a)to", "ko=hi-", "de=tabe=su", "A=to",
        "z=tp", "k=to", "foo=bar"
    ])
    func searchesTheWholeInputForLongVowelKeyTypos(input: String) {
        #expect(FuzzyQueryResolver.resolve(
            input: input,
            conversionReading: ConversionReadingResolver.resolve(input)
        ) == input)
    }

    @Test(arguments: [
        "a=b", "1+2=", "3.14", "14:30", "example.com",
        "user@example.com", "a/to", "a=", "de=", "a==to", "kana", "=to"
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

    /// Two or three keys beside the typed ones, cheapest first; three only
    /// in short inputs
    @Test
    func correctsSeveralAdjacentKeysWithinLimits() throws {
        let corrections = RomajiKeyboardTypoGenerator.multipleKeyCorrections(
            for: "z=tp"
        )
        let aTo = try #require(corrections.first { $0.reading == "a-to" })

        #expect(aTo.substitutions == 3)
        #expect(corrections.allSatisfy { (2...3).contains($0.substitutions) })
        #expect(zip(corrections, corrections.dropFirst())
            .allSatisfy { $0.cost <= $1.cost })
        // `m` is far from `a`
        #expect(!corrections.contains { $0.reading.hasPrefix("m") })
        #expect(RomajiKeyboardTypoGenerator.multipleKeyCorrections(
            for: "susumete"
        ).allSatisfy { $0.substitutions == 2 })
        #expect(RomajiKeyboardTypoGenerator.multipleKeyCorrections(
            for: "abcdefghijk"
        ).isEmpty)
    }
}
