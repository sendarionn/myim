import Testing
@testable import MyIMECore

@Suite
struct NextInputPredictionModelTests {
    @Test
    func learnsFollowingInput() {
        var model = NextInputPredictionModel()
        model.record("構造計画研究所")
        model.record("について")
        model.record("構造計画研究所")
        model.record("について")

        #expect(
            model.candidates(after: "構造計画研究所") == ["について"]
        )
    }

    @Test
    func ranksFrequencyBeforeRecency() {
        var model = NextInputPredictionModel()
        model.record("A")
        model.record("B")
        model.record("A")
        model.record("B")
        model.record("A")
        model.record("C")

        #expect(model.candidates(after: "A") == ["B", "C"])
    }

    @Test
    func clearsLearnedData() {
        var model = NextInputPredictionModel()
        model.record("A")
        model.record("B")
        model.removeAll()

        #expect(model.candidates(after: "A").isEmpty)
        #expect(model.contextCount == 0)
        #expect(model.lastInput == nil)
    }

    @Test
    func ignoresOversizedValue() {
        var model = NextInputPredictionModel()
        model.record(String(repeating: "a", count: 81))

        #expect(model.lastInput == nil)
        #expect(model.contextCount == 0)
    }

    @Test
    func breaksSequenceWithoutDeletingLearning() {
        var model = NextInputPredictionModel()
        model.record("A")
        model.record("B")
        model.breakSequence()
        model.record("C")

        #expect(model.candidates(after: "A") == ["B"])
        #expect(model.candidates(after: "B").isEmpty)
    }
}
