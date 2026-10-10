import Testing
@testable import MyIMECore

@Suite
struct RomajiKeyboardGeometryTests {
    @Test
    func distinguishesUSAndJISShiftedLongVowelKeys() {
        #expect(RomajiKeyboardGeometry.distance(
            from: "=",
            to: "-",
            layout: .jis
        ) == 0)
        #expect(RomajiKeyboardGeometry.distance(
            from: "=",
            to: "-",
            layout: .us
        ) == 1)
        #expect(RomajiKeyboardGeometry.distance(
            from: "_",
            to: "-",
            layout: .us
        ) == 0)
    }

    @Test
    func treatsZeroAsAdjacentToTheLongVowelKey() {
        for layout in RomajiKeyboardLayout.allCases {
            #expect(RomajiKeyboardGeometry.distance(
                from: "0",
                to: "-",
                layout: layout
            ) == 1)
        }
    }

    @Test
    func preservesTheExistingLetterKeyGeometry() throws {
        let adjacent = try #require(RomajiKeyboardGeometry.minimumDistance(
            from: "r",
            to: "t"
        ))
        let distant = try #require(RomajiKeyboardGeometry.minimumDistance(
            from: "r",
            to: "p"
        ))

        #expect(adjacent < distant)
    }
}
