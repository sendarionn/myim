import Foundation
import Testing
@testable import MyIMECore

@Suite
struct CalendarFormatSelectionSessionTests {
    @Test
    func ownsTheWholeLogicalCalendarSelectionLifecycle() {
        var session = CalendarFormatSelectionSession()

        session.beginCalendarSelection()
        #expect(session.isActive)
        #expect(!session.isSelectingFormat)

        session.beginFormatLoading()
        #expect(session.isSelectingFormat)
        #expect(session.candidates == [])

        session.replaceCandidates([
            .init(value: "10月3日", preferenceID: "dynamic_calendar:M/D(E)"),
            .init(value: "2026-10-03", preferenceID: "dynamic_calendar:YYYYMMDD")
        ])
        #expect(session.selectedIndex == nil)
        #expect(session.moveSelection(by: 1) == 0)
        #expect(session.selectedCandidate?.value == "10月3日")

        session.reset()
        #expect(!session.isActive)
        #expect(!session.isSelectingFormat)
        #expect(session.selectedCandidate == nil)
    }

    @Test
    func wrapsSelectionAndCalculatesTheVisiblePage() {
        var session = CalendarFormatSelectionSession()
        session.beginCalendarSelection()
        session.beginFormatLoading()
        session.replaceCandidates((0..<9).map {
            CalendarFormatCandidate(value: String($0))
        })

        session.select(index: 7)

        #expect(session.pageRange(pageSize: 4) == 4..<8)
        #expect(session.moveSelection(by: 1) == 8)
        #expect(session.pageRange(pageSize: 4) == 8..<9)
        #expect(session.moveSelection(by: 1) == 0)
    }

    @Test
    func ignoresSelectionsOutsideTheCandidateRange() {
        var session = CalendarFormatSelectionSession()
        session.beginCalendarSelection()
        session.beginFormatLoading()
        session.replaceCandidates([.init(value: "候補")])

        session.select(index: 0)
        session.select(index: 4)

        #expect(session.selectedIndex == 0)
        #expect(session.selectedCandidate?.value == "候補")
    }

    @Test
    func ordersDifferentDatesByTheSameFormatPreferenceIDs() {
        var session = CalendarFormatSelectionSession()
        session.beginCalendarSelection()
        session.beginFormatLoading()
        session.replaceCandidates([
            .init(value: "20261104", preferenceID: "dynamic_calendar:YYYYMMDD"),
            .init(value: "11/4(水)", preferenceID: "dynamic_calendar:M/D(E)")
        ], ranks: ["dynamic_calendar:M/D(E)": 10])

        #expect(session.candidates?.map(\.value) == ["11/4(水)", "20261104"])

        session.replaceCandidates([
            .init(value: "20261105", preferenceID: "dynamic_calendar:YYYYMMDD"),
            .init(value: "11/5(木)", preferenceID: "dynamic_calendar:M/D(E)")
        ], ranks: [
            "dynamic_calendar:M/D(E)": 10,
            "dynamic_calendar:YYYYMMDD": 11
        ])

        #expect(session.candidates?.map(\.value) == ["20261105", "11/5(木)"])
    }

    @Test
    func ignoresConcreteDateHistoryAndKeepsUnrankedFormatsInDefaultOrder() {
        var session = CalendarFormatSelectionSession()
        session.beginCalendarSelection()
        session.beginFormatLoading()
        session.replaceCandidates([
            .init(value: "20261104", preferenceID: "dynamic_calendar:YYYYMMDD"),
            .init(value: "11/4(水)", preferenceID: "dynamic_calendar:M/D(E)"),
            .init(value: "2026-11-04")
        ], ranks: [
            "20261104": 100,
            "dynamic_calendar:M/D(E)": 10
        ])

        #expect(session.candidates?.map(\.value) == [
            "11/4(水)", "20261104", "2026-11-04"
        ])
    }

    @Test
    func formatPreferenceSurvivesHistorySerializationWithoutTheDateValue()
        throws
    {
        let preferenceID = "dynamic_calendar:M/D(E)"
        var history = CandidateSelectionHistory()
        history.record(preferenceID, readings: [])
        let restored = try JSONDecoder().decode(
            CandidateSelectionHistory.self,
            from: JSONEncoder().encode(history)
        )

        #expect(restored.ranks[preferenceID] != nil)
        #expect(restored.ranks["11/4(水)"] == nil)

        var session = CalendarFormatSelectionSession()
        session.beginCalendarSelection()
        session.beginFormatLoading()
        session.replaceCandidates([
            .init(value: "20261105", preferenceID: "dynamic_calendar:YYYYMMDD"),
            .init(value: "11/5(木)", preferenceID: preferenceID)
        ], ranks: restored.ranks)

        #expect(session.candidates?.first?.value == "11/5(木)")
    }
}
