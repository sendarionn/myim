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

@Suite
struct LiveConversionStatePreviewTests {
    @Test
    func aChosenConversionIsCorrectedInItsPhrases() throws {
        var state = LiveConversionState()
        state.update(
            input: "kyouhaiitenki",
            reading: "きょうはいいてんき",
            candidates: ["今日はいい天気", "今日は良い天気"],
            phrases: [
                [.init(surface: "今日は", reading: "きょうは"), .init(surface: "いい", reading: "いい"),
                 .init(surface: "天気", reading: "てんき")],
                [.init(surface: "今日は", reading: "きょうは"), .init(surface: "良い天気", reading: "よいてんき")]
            ]
        )
        let second = try #require(state.preview(of: "今日は良い天気", for: "kyouhaiitenki"))
        #expect(second.segments.count == 2)
        // Another candidate is one phrase of the whole reading
        let other = try #require(state.preview(of: "京は飯店来", for: "kyouhaiitenki"))
        #expect(other.segments == [.init(surface: "京は飯店来", reading: "きょうはいいてんき")])
        #expect(state.preview(of: "今日は良い天気", for: "kyouhaiitenk") == nil)
    }
}
