import Foundation
import Testing
@testable import MyIMECore

@Suite struct InputLocationQueryPolicyTests {
    @Test func queriesMarkedTextBeforeTheSelection() {
        #expect(InputLocationQueryPolicy.characterIndices(
            markedRange: NSRange(location: 80, length: 4),
            selectedRange: NSRange(location: 84, length: 0)
        ) == [80, 84])
    }

    @Test func fallsBackToTheSelectionWithoutMarkedText() {
        #expect(InputLocationQueryPolicy.characterIndices(
            markedRange: NSRange(location: NSNotFound, length: 0),
            selectedRange: NSRange(location: 42, length: 0)
        ) == [42])
    }

    @Test func avoidsQueryingTheSameIndexTwice() {
        #expect(InputLocationQueryPolicy.characterIndices(
            markedRange: NSRange(location: 42, length: 4),
            selectedRange: NSRange(location: 42, length: 0)
        ) == [42])
    }

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

    @Test func recognizesOnlyTheTopLeftScreenPlaceholder() {
        #expect(InputLocationQueryPolicy.isTopLeftScreenPlaceholder(
            x: 0,
            y: 880,
            width: 1,
            height: 20,
            screenMinX: 0,
            screenMaxY: 900
        ))
        #expect(!InputLocationQueryPolicy.isTopLeftScreenPlaceholder(
            x: 320,
            y: 480,
            width: 1,
            height: 20,
            screenMinX: 0,
            screenMaxY: 900
        ))
    }

    @Test func recognizesGoogleDocsPlaceholderBelowBrowserChrome() {
        #expect(InputLocationQueryPolicy.isTopLeftScreenPlaceholder(
            x: 0,
            y: 786,
            width: 1,
            height: 16,
            screenMinX: 0,
            screenMaxY: 900
        ))
    }

    @Test func preservesLegitimateLeftEdgeLocationAwayFromTopBand() {
        #expect(!InputLocationQueryPolicy.isTopLeftScreenPlaceholder(
            x: 0,
            y: 420,
            width: 1,
            height: 20,
            screenMinX: 0,
            screenMaxY: 900
        ))
    }

    @Test func preservesWideRectangleAtTheTopLeft() {
        #expect(!InputLocationQueryPolicy.isTopLeftScreenPlaceholder(
            x: 0,
            y: 786,
            width: 40,
            height: 16,
            screenMinX: 0,
            screenMaxY: 900
        ))
    }
}
