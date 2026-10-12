import Testing
@testable import MyIMECore

@Suite
struct MarkedTextSegmentsTests {
    @Test(arguments: [
        ("watashiha,", ",", 0..<9, 9..<10),
        ("私は,", ",", 0..<2, 2..<3),
        ("tokyo.", ".", 0..<5, 5..<6),
        ("watashiha!?", "!?", 0..<9, 9..<11),
        ("私は!?", "!?", 0..<2, 2..<4),
        ("example.com.", ".", 0..<11, 11..<12),
        ("！?", "?", 0..<1, 1..<2),
        ("😀は,", ",", 0..<3, 3..<4)
    ])
    func separatesTheConversionTargetFromThePendingPart(
        text: String,
        pending: String,
        target: Range<Int>,
        pendingRange: Range<Int>
    ) {
        #expect(MarkedTextSegments(text: text, pendingSuffix: pending)
            == MarkedTextSegments(target: target, pending: pendingRange))
    }

    @Test(arguments: [
        ("watashiha", ""),
        (",", ","),
        ("私は", ","),
        ("、", "")
    ])
    func leavesTextWithoutAPendingPartWhole(text: String, pending: String) {
        #expect(MarkedTextSegments(text: text, pendingSuffix: pending) == nil)
    }
}
