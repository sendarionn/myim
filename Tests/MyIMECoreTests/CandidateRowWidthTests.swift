import Testing
@testable import MyIMECore

@Suite
struct CandidateRowWidthTests {
    @Test
    func addsTheAccessoryOutsideTheOrdinaryTextWidth() {
        let ordinary = CandidateRowWidth.resolve(
            textWidth: 200,
            accessoryWidth: 0,
            horizontalPadding: 9,
            minimumWidth: 32,
            maximumTextWidth: 240,
            maximumPanelWidth: 360
        )
        let alternateCommit = CandidateRowWidth.resolve(
            textWidth: 200,
            accessoryWidth: 14,
            horizontalPadding: 9,
            minimumWidth: 32,
            maximumTextWidth: 240,
            maximumPanelWidth: 360
        )

        #expect(ordinary == 218)
        #expect(alternateCommit == 232)
    }

    @Test
    func doesNotTakeAccessoryWidthFromAMaximumWidthTextCandidate() {
        let ordinary = CandidateRowWidth.resolve(
            textWidth: 300,
            accessoryWidth: 0,
            horizontalPadding: 9,
            minimumWidth: 32,
            maximumTextWidth: 240,
            maximumPanelWidth: 360
        )
        let alternateCommit = CandidateRowWidth.resolve(
            textWidth: 300,
            accessoryWidth: 14,
            horizontalPadding: 9,
            minimumWidth: 32,
            maximumTextWidth: 240,
            maximumPanelWidth: 360
        )

        #expect(ordinary == 240)
        #expect(alternateCommit == 254)
    }

    @Test
    func keepsTheWholeRowInsideThePanelLimit() {
        let width = CandidateRowWidth.resolve(
            textWidth: 300,
            accessoryWidth: 140,
            horizontalPadding: 9,
            minimumWidth: 32,
            maximumTextWidth: 240,
            maximumPanelWidth: 360
        )

        #expect(width == 360)
    }
}
