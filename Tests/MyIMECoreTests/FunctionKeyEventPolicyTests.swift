import Testing
@testable import MyIMECore

struct FunctionKeyEventPolicyTests {
    @Test func ignoresF1ThroughF5() {
        for keyCode: UInt16 in [122, 120, 99, 118, 96] {
            #expect(FunctionKeyEventPolicy.shouldIgnore(keyCode: keyCode))
        }
    }

    @Test func keepsF6ThroughF10AvailableForInputFormConversion() {
        for keyCode: UInt16 in [97, 98, 100, 101, 109] {
            #expect(!FunctionKeyEventPolicy.shouldIgnore(keyCode: keyCode))
        }
    }
}
