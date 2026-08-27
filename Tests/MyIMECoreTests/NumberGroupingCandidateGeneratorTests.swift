import Testing
@testable import MyIMECore

@Suite
struct NumberGroupingCandidateGeneratorTests {
    @Test
    func groupsIntegerDigitsByThree() {
        #expect(NumberGroupingCandidateGenerator.candidates(for: "1000") == ["1,000"])
        #expect(NumberGroupingCandidateGenerator.candidates(for: "1234567") == ["1,234,567"])
    }

    @Test
    func preservesSignAndFraction() {
        #expect(NumberGroupingCandidateGenerator.candidates(for: "-12345") == ["-12,345"])
        #expect(NumberGroupingCandidateGenerator.candidates(for: "1234.56") == ["1,234.56"])
    }

    @Test
    func rejectsUnsupportedInput() {
        #expect(NumberGroupingCandidateGenerator.candidates(for: "999").isEmpty)
        #expect(NumberGroupingCandidateGenerator.candidates(for: "1,000").isEmpty)
        #expect(NumberGroupingCandidateGenerator.candidates(for: "1234.").isEmpty)
        #expect(NumberGroupingCandidateGenerator.candidates(for: "12a4").isEmpty)
    }
}
