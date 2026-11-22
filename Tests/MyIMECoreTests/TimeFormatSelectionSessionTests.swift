import Foundation
import Testing
@testable import MyIMECore

@Suite("TimeFormatSelectionSessionTests")
struct TimeFormatSelectionSessionTests {
    @Test func ownsTimeAndFormatSelectionLifecycle() throws {
        var session = TimeFormatSelectionSession()
        session.beginTimeSelection()
        #expect(session.isActive)
        #expect(!session.isSelectingFormat)

        let time = try #require(TimeSelectionState(hour: 14, minute: 35))
        session.beginFormatLoading(for: time)
        #expect(session.isSelectingFormat)
        session.replaceCandidates([
            .init(value: "14:35", preferenceID: "time_ui:single:numeric"),
            .init(value: "14時35分", preferenceID: "time_ui:single:kanji")
        ])
        session.moveSelection(by: 1)
        #expect(session.selectedIndex == 0)

        session.reset()
        #expect(!session.isActive)
        #expect(!session.isSelectingFormat)
    }

    /// Esc on the formats of a range goes back to the rail at that range,
    /// and formats requested for it before are discarded
    @Test func escapeReturnsToTheRailWithTheChosenRange() throws {
        var session = TimeFormatSelectionSession()
        session.beginTimeSelection()
        let range = try #require(TimeRangeSelection(start: 780, end: 840))
        session.beginFormatLoading(for: range)
        #expect(session.accepts(formatsFor: range))

        let returned = session.returnToRangeSelection()
        let returnedTime = session.returnToTimeSelection()

        #expect(returned == range)
        #expect(returnedTime == nil)
        #expect(!session.accepts(formatsFor: range))

        let time = try #require(TimeSelectionState(hour: 13, minute: 0))
        session.beginFormatLoading(for: time)
        #expect(session.range == nil)
        #expect(!session.accepts(formatsFor: range))
    }

    /// Esc on the formats of 14:30 reopens the rail at 14:30, and the
    /// formats made next are for the time chosen then
    @Test func escapeReturnsToTheClockWithTheChosenTime() throws {
        var session = TimeFormatSelectionSession()
        session.beginTimeSelection()
        let first = try #require(TimeSelectionState(hour: 14, minute: 30))
        session.beginFormatLoading(for: first)
        session.replaceCandidates([
            .init(value: "14:30", preferenceID: "time_ui:single:numeric"),
            .init(value: "14時30分", preferenceID: "time_ui:single:kanji"),
            .init(value: "14時半", preferenceID: "time_ui:single:half")
        ])
        session.select(index: 2)

        #expect(session.returnToTimeSelection() == first)
        #expect(session.isActive)
        #expect(!session.isSelectingFormat)
        #expect(session.selectedIndex == nil)

        let second = try #require(TimeSelectionState(hour: 14, minute: 35))
        session.beginFormatLoading(for: second)
        #expect(session.accepts(formatsFor: second))
    }

    @Test func formatsRequestedBeforeGoingBackAreDiscarded() throws {
        var session = TimeFormatSelectionSession()
        session.beginTimeSelection()
        let first = try #require(TimeSelectionState(hour: 14, minute: 30))
        session.beginFormatLoading(for: first)

        // Esc while the formats still load
        _ = session.returnToTimeSelection()
        #expect(!session.accepts(formatsFor: first))

        let second = try #require(TimeSelectionState(hour: 9, minute: 5))
        session.beginFormatLoading(for: second)
        #expect(!session.accepts(formatsFor: first))
        #expect(session.accepts(formatsFor: second))
    }

    @Test func nothingToReturnToOnceTheInputEnds() throws {
        var session = TimeFormatSelectionSession()
        session.beginTimeSelection()
        session.beginFormatLoading(
            for: try #require(TimeSelectionState(hour: 0, minute: 30))
        )

        session.reset()

        #expect(session.returnToTimeSelection() == nil)
    }

    @Test func ordersDifferentTimesByTheSameSingleFormatPreferenceIDs() {
        var session = TimeFormatSelectionSession()
        session.beginTimeSelection()
        session.replaceCandidates([
            .init(value: "13時20分", preferenceID: "time_ui:single:kanji"),
            .init(value: "13:20", preferenceID: "time_ui:single:numeric")
        ], ranks: ["time_ui:single:numeric": 10])

        #expect(session.candidates?.map(\.value) == ["13:20", "13時20分"])

        session.replaceCandidates([
            .init(value: "15時40分", preferenceID: "time_ui:single:kanji"),
            .init(value: "15:40", preferenceID: "time_ui:single:numeric")
        ], ranks: [
            "time_ui:single:numeric": 10,
            "time_ui:single:kanji": 11
        ])

        #expect(session.candidates?.map(\.value) == ["15時40分", "15:40"])
    }

    @Test func ordersRangeFormatAndSeparatorByTheirSharedPreferenceID() {
        var session = TimeFormatSelectionSession()
        session.beginTimeSelection()
        session.replaceCandidates([
            .init(
                value: "13時20分〜14時30分",
                preferenceID: "time_ui:range:kanji:wave"
            ),
            .init(
                value: "13:20 - 14:30",
                preferenceID: "time_ui:range:numeric:hyphen"
            )
        ], ranks: ["time_ui:range:numeric:hyphen": 20])

        #expect(session.candidates?.map(\.value) == [
            "13:20 - 14:30", "13時20分〜14時30分"
        ])
    }

    @Test func formatPreferenceSurvivesHistoryWithoutTheConcreteTime() throws {
        let preferenceID = "time_ui:single:numeric"
        var history = CandidateSelectionHistory()
        history.record(preferenceID, readings: [])
        let restored = try JSONDecoder().decode(
            CandidateSelectionHistory.self,
            from: JSONEncoder().encode(history)
        )

        #expect(restored.ranks[preferenceID] != nil)
        #expect(restored.ranks["13:20"] == nil)

        var session = TimeFormatSelectionSession()
        session.beginTimeSelection()
        session.replaceCandidates([
            .init(value: "15時40分", preferenceID: "time_ui:single:kanji"),
            .init(value: "15:40", preferenceID: preferenceID)
        ], ranks: restored.ranks)

        #expect(session.candidates?.first?.value == "15:40")
    }
}
