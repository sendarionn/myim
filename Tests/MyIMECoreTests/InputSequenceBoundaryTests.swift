import Testing
@testable import MyIMECore

@Suite
struct InputSequenceBoundaryTests {
    @Test
    func detectsLineBreakAtEnd() {
        #expect(InputSequenceBoundary.endsWithLineBreak("前の行\n"))
        #expect(InputSequenceBoundary.endsWithLineBreak("前の行\r"))
        #expect(InputSequenceBoundary.endsWithLineBreak("前の行\u{2028}"))
    }

    @Test
    func ignoresTextWithoutTrailingLineBreak() {
        #expect(!InputSequenceBoundary.endsWithLineBreak("前の行"))
        #expect(!InputSequenceBoundary.endsWithLineBreak("前の行\n次の行"))
        #expect(!InputSequenceBoundary.endsWithLineBreak(""))
    }
}
