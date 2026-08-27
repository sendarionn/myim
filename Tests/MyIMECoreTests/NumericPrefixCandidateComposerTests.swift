import Testing
@testable import MyIMECore

@Suite
struct NumericPrefixCandidateComposerTests {
    @Test
    func preservesNumberAndConvertsReading() {
        #expect(
            NumericPrefixCandidateComposer.candidates(
                for: "3nin",
                convertedReadings: ["人", "にん", "人"]
            ) == ["3人", "3にん"]
        )
        #expect(
            NumericPrefixCandidateComposer.candidates(
                for: "1byou",
                convertedReadings: ["秒"]
            ) == ["1秒"]
        )
    }

    @Test
    func supportsSignedAndDecimalNumbers() {
        #expect(
            NumericPrefixCandidateComposer.parts(of: "-2.5jikan")
                == .init(number: "-2.5", reading: "jikan")
        )
    }

    @Test
    func rejectsInputWithoutBothParts() {
        #expect(NumericPrefixCandidateComposer.parts(of: "123") == nil)
        #expect(NumericPrefixCandidateComposer.parts(of: "nin") == nil)
    }
}
