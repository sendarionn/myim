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

    /// 1 to 12 inside and 13 to 24 outside, 24 standing for 0 o'clock
    @Test func ringsShowTwentyFourLabels() {
        #expect((0..<12).map { TimeHourRing.inner.label(atDialStep: $0) }
            == ["12", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11"])
        #expect((0..<12).map { TimeHourRing.outer.label(atDialStep: $0) }
            == ["24", "13", "14", "15", "16", "17", "18", "19", "20", "21",
                "22", "23"])
        #expect(TimeHourRing.inner.hour(atDialStep: 0) == 12)
        #expect(TimeHourRing.outer.hour(atDialStep: 0) == 0)
    }

    /// Every label is clicked where it is drawn, 12 and 24 apart
    @Test func everyLabelSelectsItsOwnHour() {
        var hours: [Int] = []
        for ring in TimeHourRing.allCases {
            for step in 0..<12 {
                let center = layout.labelCenter(atDialStep: step, ring: ring)
                let hour = layout.hour(atX: center.x, y: center.y)
                #expect(hour == ring.hour(atDialStep: step))
                #expect(layout.hour(
                    atX: center.x + layout.labelHitRadius - 1,
                    y: center.y
                ) == hour)
                hours.append(hour ?? -1)
            }
        }
        #expect(Set(hours) == Set(0...23))
    }

    @Test func clickedHourKeepsTheMinute() throws {
        var state = try #require(TimeSelectionState(hour: 10, minute: 37))
        state.selectHour(15)
        #expect(state.digitalText == "15:37")
        state.selectHour(0)
        #expect(state.digitalText == "00:37")
    }

    /// Click areas, and so the selection circles inside them, stay apart
    /// on and across rings
    @Test func labelsAndHighlightsDoNotTouch() {
        let centers = TimeHourRing.allCases.flatMap { ring in
            (0..<12).map { layout.labelCenter(atDialStep: $0, ring: ring) }
        }
        for (index, first) in centers.enumerated() {
            for second in centers[(index + 1)...] {
                let dx = abs(first.x - second.x)
                let dy = abs(first.y - second.y)
                #expect(hypot(dx, dy) > layout.labelHitRadius * 2)
            }
        }
        #expect(layout.highlightRadius <= layout.labelHitRadius)
        #expect(layout.outerLabelRadius + layout.labelHitRadius
            < layout.dialRadius)
    }

    /// The selection circle fits one and two digit labels alike
    @Test func highlightHoldsTwoDigitLabels() {
        let twoDigitWidth = layout.labelFontSize * 1.3
        #expect(layout.highlightRadius * 2 > twoDigitWidth)
        #expect(layout.innerLabelRadius - layout.highlightRadius
            > layout.minuteRingOuterRadius)
    }

    /// 1 to 12 belong to the inner ring and 13 to 23 and 0 to the outer,
    /// so the ring of the selected hour is the one shown darker
    @Test func selectedHourGivesItsRing() {
        for hour in 0...23 {
            let ring = TimeHourRing(hour: hour)
            #expect(ring == ((1...12).contains(hour) ? .inner : .outer))
            #expect((0..<12).contains { ring.hour(atDialStep: $0) == hour })
        }
    }

    /// From the centre: the HH:MM display, a wide minute ring, then labels
    @Test func layersFitInsideEachOther() {
        #expect(layout.minuteRingInnerRadius > layout.timeDisplayRadius)
        #expect(layout.minuteRingOuterRadius - layout.minuteRingInnerRadius
            >= 30)
        #expect(layout.minuteRingOuterRadius
            < layout.innerLabelRadius - layout.labelHitRadius)
        #expect(layout.outerLabelRadius + layout.labelHitRadius
            < layout.dialRadius)
    }

    @Test func pressesAreSortedByWhereTheyStart() {
        let middle = (layout.minuteRingInnerRadius
            + layout.minuteRingOuterRadius) / 2
        let inner3 = layout.labelCenter(atDialStep: 3, ring: .inner)
        let outer6 = layout.labelCenter(atDialStep: 6, ring: .outer)
        let between = (layout.innerLabelRadius + layout.outerLabelRadius) / 2

        #expect(layout.region(atX: 0, y: 0) == .timeDisplay)
        #expect(layout.region(atX: layout.timeDisplayRadius, y: 0) == .timeDisplay)
        #expect(layout.region(atX: 0, y: middle) == .minuteRing)
        #expect(layout.region(atX: inner3.x, y: inner3.y) == .hourLabel(3))
        #expect(layout.region(atX: outer6.x, y: outer6.y) == .hourLabel(18))
        #expect(layout.region(atX: 0, y: between) == .none)
        #expect(layout.region(atX: 0, y: layout.dialRadius) == .none)
    }

    @Test(arguments: [
        (0.0, 50.0, 0), (50.0, 0.0, 15), (0.0, -50.0, 30), (-50.0, 0.0, 45),
        (50.0 * sin(37.0 * .pi / 30), 50.0 * cos(37.0 * .pi / 30), 37),
        (-1.0, 100.0, 0)
    ])
    func angleGivesEveryMinute(x: Double, y: Double, minute: Int) {
        #expect(layout.minute(atX: x, y: y) == minute)
    }

    /// A press on the minute ring sets the minute at once and follows the
    /// drag even off the ring, never selecting an hour
    @Test func minuteRingPressSetsAndDragsTheMinute() {
        let middle = (layout.minuteRingInnerRadius
            + layout.minuteRingOuterRadius) / 2
        let gesture = TimeDialPointerGesture(
            atX: middle, y: 0, layout: layout
        )

        #expect(gesture.minuteOnPress(
            atX: middle, y: 0, layout: layout
        ) == 15)
        #expect(gesture.move(toX: 0, y: -200, layout: layout) == 30)
        let outer24 = layout.labelCenter(atDialStep: 0, ring: .outer)
        #expect(gesture.release(
            atX: outer24.x, y: outer24.y, layout: layout
        ) == .none)
    }

    @Test func labelClickSelectsItsHourWhenReleasedOnIt() {
        let outer24 = layout.labelCenter(atDialStep: 0, ring: .outer)
        let gesture = TimeDialPointerGesture(
            atX: outer24.x, y: outer24.y, layout: layout
        )

        #expect(gesture.minuteOnPress(
            atX: outer24.x, y: outer24.y, layout: layout
        ) == nil)
        #expect(gesture.move(toX: 0, y: 60, layout: layout) == nil)
        #expect(gesture.release(
            atX: outer24.x + 3, y: outer24.y, layout: layout
        ) == .selectHour(0))
        #expect(gesture.release(atX: 0, y: 60, layout: layout) == .none)
    }

    @Test func innerLabelsAreClickableToo() {
        let inner9 = layout.labelCenter(atDialStep: 9, ring: .inner)
        let gesture = TimeDialPointerGesture(
            atX: inner9.x, y: inner9.y, layout: layout
        )

        #expect(gesture.release(
            atX: inner9.x, y: inner9.y, layout: layout
        ) == .selectHour(9))
    }

    @Test func pressOnTheTimeDisplayNeitherSetsNorSelects() {
        let gesture = TimeDialPointerGesture(atX: 5, y: 5, layout: layout)

        #expect(gesture.minuteOnPress(atX: 5, y: 5, layout: layout) == nil)
        #expect(gesture.move(toX: 90, y: 0, layout: layout) == nil)
        #expect(gesture.release(atX: 5, y: 5, layout: layout) == .none)
    }
}
