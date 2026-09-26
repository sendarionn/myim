import Testing
@testable import MyIMECore

struct InputKeyTests {
    @Test func classifiesEditingAndNavigationKeys() {
        #expect(InputKey(keyCode: 48) == .tab)
        #expect(InputKey(keyCode: 49) == .space)
        #expect(InputKey(keyCode: 123) == .leftArrow)
        #expect(InputKey(keyCode: 124) == .rightArrow)
        #expect(InputKey(keyCode: 125) == .downArrow)
        #expect(InputKey(keyCode: 126) == .upArrow)
        #expect(InputKey(keyCode: 51) == .delete)
        #expect(InputKey(keyCode: 53) == .escape)
    }

    @Test func treatsBothReturnKeysEqually() {
        #expect(InputKey(keyCode: 36) == .returnKey)
        #expect(InputKey(keyCode: 76) == .returnKey)
    }

    @Test func groupsInputFormFunctionKeys() {
        for keyCode: UInt16 in [97, 98, 100, 101, 109] {
            #expect(InputKey(keyCode: keyCode) == .inputFormFunction)
        }
        #expect(InputKey(keyCode: 96) == .other)
    }

    @Test func leavesPrintableKeysUnclassified() {
        #expect(InputKey(keyCode: 0) == .other)
        #expect(InputKey(keyCode: 14) == .other)
    }
}
