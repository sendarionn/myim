import Testing
@testable import MyIMECore

struct CalculatorCandidateGeneratorTests {
    @Test
    func calculatesBasicExpressions() {
        #expect(CalculatorCandidateGenerator.candidates(for: "2+1=") == ["3"])
        #expect(CalculatorCandidateGenerator.candidates(for: "2+3*4=") == ["14"])
        #expect(CalculatorCandidateGenerator.candidates(for: "(2+3)*4=") == ["20"])
    }

    @Test
    func calculatesDecimalsAndUnaryOperators() {
        #expect(CalculatorCandidateGenerator.candidates(for: "5/2=") == ["2.5"])
        #expect(CalculatorCandidateGenerator.candidates(for: "-2+1=") == ["-1"])
        #expect(CalculatorCandidateGenerator.candidates(for: "0.1+0.2=") == ["0.3"])
    }

    @Test
    func rejectsIncompleteOrUnsafeExpressions() {
        #expect(CalculatorCandidateGenerator.candidates(for: "2+1").isEmpty)
        #expect(CalculatorCandidateGenerator.candidates(for: "1/0=").isEmpty)
        #expect(CalculatorCandidateGenerator.candidates(for: "1+a=").isEmpty)
        #expect(CalculatorCandidateGenerator.candidates(for: "=").isEmpty)
    }
}
