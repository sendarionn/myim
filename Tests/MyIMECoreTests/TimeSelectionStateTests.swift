import Foundation
import Testing
@testable import MyIMECore

@Suite("TimeSelectionStateTests")
struct TimeSelectionStateTests {
    private let layout = TimeDialLayout()

    @Test func validatesTheWholeTwentyFourHourRange() {
        #expect(TimeSelectionState(hour: 0, minute: 0) != nil)
        #expect(TimeSelectionState(hour: 10, minute: 37) != nil)
        #expect(TimeSelectionState(hour: 23, minute: 59) != nil)
        #expect(TimeSelectionState(hour: 24, minute: 0) == nil)
        #expect(TimeSelectionState(hour: 0, minute: 60) == nil)
    }

    @Test func ringsShowAllHoursAndFiveMinuteValues() {
        #expect((0..<12).map { TimeDialRing.outerHour.label(atDialStep: $0) }
            == ["12", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11"])
        #expect((0..<12).map { TimeDialRing.middleHour.label(atDialStep: $0) }
            == ["24", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23"])
        #expect((0..<12).map { TimeDialRing.minute.label(atDialStep: $0) }
            == ["00", "05", "10", "15", "20", "25", "30", "35", "40", "45", "50", "55"])
        #expect(TimeDialRing.outerHour.selection(atDialStep: 0) == .hour(12))
        #expect(TimeDialRing.middleHour.selection(atDialStep: 0) == .hour(0))
    }

    @Test func allThirtySixLabelsSelectTheirDisplayedValue() {
        var selections: [TimeDialSelection] = []
        for ring in TimeDialRing.allCases {
            for step in 0..<12 {
                let center = layout.labelCenter(atDialStep: step, ring: ring)
                let selection = layout.selection(atX: center.x, y: center.y)
                #expect(selection == ring.selection(atDialStep: step))
                selections.append(selection!)
            }
        }
        #expect(Set(selections.compactMap {
            if case let .hour(value) = $0 { value } else { nil }
        }) == Set(0...23))
        #expect(Set(selections.compactMap {
            if case let .minute(value) = $0 { value } else { nil }
        }) == Set(stride(from: 0, through: 55, by: 5)))
    }

    @Test func ringsHaveEqualWidthsAndOrderedRadii() {
        for ring in TimeDialRing.allCases {
            #expect(layout.outerRadius(of: ring) - layout.innerRadius(of: ring)
                == layout.ringWidth)
        }
        #expect(layout.innerRadius(of: .outerHour)
            == layout.outerRadius(of: .middleHour))
        #expect(layout.innerRadius(of: .middleHour)
            == layout.outerRadius(of: .minute))
        #expect(layout.innerRadius(of: .minute) == layout.centerRadius)
    }

    @Test func annularClickAreasDoNotOverlap() {
        let outerBoundary = layout.innerRadius(of: .outerHour)
        let middleBoundary = layout.innerRadius(of: .middleHour)
        let innerBoundary = layout.innerRadius(of: .minute)

        #expect(layout.selection(atX: 0, y: outerBoundary + 0.1) == .hour(12))
        #expect(layout.selection(atX: 0, y: outerBoundary) == .hour(0))
        #expect(layout.selection(atX: 0, y: middleBoundary) == .minute(0))
        #expect(layout.selection(atX: 0, y: innerBoundary) == nil)
        #expect(layout.selection(atX: 0, y: layout.outerRadius + 0.1) == nil)
    }

    @Test func highlightFitsEveryRing() {
        #expect(layout.highlightRadius * 2 < layout.ringWidth)
        #expect(layout.labelFontSize * 1.3 < layout.highlightRadius * 2)
    }

    @Test func clickedHourKeepsTheMinute() throws {
        var state = try #require(TimeSelectionState(hour: 10, minute: 35))
        state.selectHour(15)
        #expect(state.digitalText == "15:35")
        state.selectHour(0)
        #expect(state.digitalText == "00:35")
    }

    @Test func clickedMinuteKeepsTheHour() throws {
        var state = try #require(TimeSelectionState(hour: 14, minute: 30))
        state.selectMinute(55)
        #expect(state.digitalText == "14:55")
    }

    @Test(arguments: [
        (14, 32, "14:30"),
        (14, 33, "14:35"),
        (23, 58, "00:00"),
        (0, 0, "00:00"),
        (9, 5, "09:05")
    ])
    func initialTimeRoundsToNearestFiveMinutes(
        hour: Int,
        minute: Int,
        expected: String
    ) throws {
        let state = try #require(TimeSelectionState(hour: hour, minute: minute))
        #expect(state.roundedToNearestFiveMinutes().digitalText == expected)
    }

    @Test func returningTimeIsNotRoundedAgain() throws {
        let selected = try #require(TimeSelectionState(hour: 10, minute: 37))
        #expect(selected.digitalText == "10:37")
    }
}
