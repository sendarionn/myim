import Testing
@testable import MyIMECore

@Suite
struct ConversionReadingResolverTests {
    @Test
    func keepsMixedLettersAndDigitsAsOneDictionaryReading() {
        #expect(ConversionReadingResolver.resolve("E06S") == "E06S")
    }

    @Test
    func keepsOrdinaryRomajiInputUnchanged() {
        #expect(ConversionReadingResolver.resolve("goriyou") == "goriyou")
    }

    @Test
    func preservesNonReadingSuffixForOrdinaryConversion() {
        #expect(ConversionReadingResolver.resolve("kigou/") == "kigou")
    }
}
