import Testing
@testable import MyIMECore

@Suite
struct LiveConversionStateTests {
    @Test
    func onlyTheConversionOfTheLettersAsTheyAreIsShown() {
        var state = LiveConversionState()
        state.update(input: "kaigino", candidates: ["会議の", "海技の"])
        #expect(state.displayText(for: "kaigino") == "会議の")
        // Letters typed since follow the last conversion until converted,
        // and are not offered as its candidates
        #expect(state.displayText(for: "kaiginos") == "会議のs")
        #expect(state.candidates(for: "kaiginos").isEmpty)
        #expect(state.displayText(for: "kaigi") == nil)
    }
}
