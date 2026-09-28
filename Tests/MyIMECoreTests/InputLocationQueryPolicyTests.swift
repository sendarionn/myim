import Foundation
import Testing
@testable import MyIMECore

@Suite struct InputLocationQueryPolicyTests {
    @Test func queriesTheCurrentInsertionLocation() {
        #expect(InputLocationQueryPolicy.characterIndex(
            for: NSRange(location: 42, length: 0)
        ) == 42)
    }

    @Test func fallsBackOnlyWhenSelectionLocationIsUnavailable() {
        #expect(InputLocationQueryPolicy.characterIndex(
            for: NSRange(location: NSNotFound, length: 0)
        ) == 0)
    }

    @Test func rejectsMissingAndNonFiniteRectangles() {
        #expect(!InputLocationQueryPolicy.isValidRectangle(
            x: 0, y: 0, width: 0, height: 0
        ))
        #expect(!InputLocationQueryPolicy.isValidRectangle(
            x: .nan, y: 0, width: 1, height: 20
        ))
        #expect(InputLocationQueryPolicy.isValidRectangle(
            x: 120, y: 240, width: 1, height: 20
        ))
    }
}
