import Testing
@testable import MyIMECore

struct CandidateSelectionReadingTests {
    @Test
    func usesOriginalInputForPureNumericInput() {
        #expect(CandidateSelectionReading.resolve(
            conversionReading: "",
            originalInput: "2"
        ) == "2")
    }

    @Test
    func preservesConversionReadingForRomanInput() {
        #expect(CandidateSelectionReading.resolve(
            conversionReading: "kouho",
            originalInput: "kouho"
        ) == "kouho")
    }
}
