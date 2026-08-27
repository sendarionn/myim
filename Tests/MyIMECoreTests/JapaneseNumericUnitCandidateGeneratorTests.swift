import Testing
@testable import MyIMECore

@Suite
struct JapaneseNumericUnitCandidateGeneratorTests {
    @Test
    func createsJapaneseUnitCandidates() {
        #expect(
            JapaneseNumericUnitCandidateGenerator.candidates(for: "10000")
                == ["10千", "1万"]
        )
        #expect(
            JapaneseNumericUnitCandidateGenerator.candidates(for: "100000")
                == ["100千", "10万"]
        )
        #expect(
            JapaneseNumericUnitCandidateGenerator.candidates(for: "100000000")
                == ["1億"]
        )
    }

    @Test
    func rejectsNonIntegralAndUnsupportedValues() {
        #expect(JapaneseNumericUnitCandidateGenerator.candidates(for: "999").isEmpty)
        #expect(JapaneseNumericUnitCandidateGenerator.candidates(for: "01000").isEmpty)
        #expect(JapaneseNumericUnitCandidateGenerator.candidates(for: "1.0").isEmpty)
        #expect(JapaneseNumericUnitCandidateGenerator.candidates(for: "1000a").isEmpty)
    }
}
