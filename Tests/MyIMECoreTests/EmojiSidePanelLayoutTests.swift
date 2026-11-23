import CoreGraphics
import Testing
@testable import MyIMECore

@Suite
struct EmojiSidePanelLayoutTests {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let variation = CGSize(width: 180, height: 76)
    private let comparison = CGSize(width: 240, height: 88)

    private func frames(panelX: CGFloat, screen: CGRect? = nil) -> (CGRect, EmojiSidePanelLayout.Frames) {
        let panel = CGRect(x: panelX, y: 400, width: 240, height: 240)
        return (panel, EmojiSidePanelLayout.frames(
            panel: panel,
            variationSize: variation,
            variationTop: 600,
            comparisonSize: comparison,
            visibleFrame: screen ?? self.screen,
            spacing: 8
        ))
    }

    private func expectApart(_ panel: CGRect, _ result: EmojiSidePanelLayout.Frames, in screen: CGRect) {
        guard let variation = result.variation, let comparison = result.comparison else {
            Issue.record("both panels are placed")
            return
        }
        #expect(!variation.intersects(comparison))
        #expect(!variation.intersects(panel))
        #expect(!comparison.intersects(panel))
        #expect(screen.contains(variation))
        #expect(screen.contains(comparison))
    }

    /// The variations beside the panel, the comparison outside them
    @Test
    func variationsComeBetweenThePanelAndTheComparison() {
        let (panel, result) = frames(panelX: 100)
        expectApart(panel, result, in: screen)
        #expect(result.variation?.minX == panel.maxX + 8)
        #expect(result.comparison?.minX == result.variation!.maxX + 8)
    }

    @Test
    func atTheRightEdgeTheyGoLeft() {
        let (panel, result) = frames(panelX: 1190)
        expectApart(panel, result, in: screen)
        #expect(result.variation!.maxX == panel.minX - 8)
        #expect(result.comparison!.maxX == result.variation!.minX - 8)
    }

    /// Without room for a row on either side, they stack in one column
    @Test
    func withoutRoomForARowTheyStack() {
        let narrow = CGRect(x: 0, y: 0, width: 760, height: 900)
        let (panel, result) = frames(panelX: 260, screen: narrow)
        expectApart(panel, result, in: narrow)
    }

    @Test
    func theComparisonAloneSitsBesideThePanel() {
        let panel = CGRect(x: 100, y: 400, width: 240, height: 240)
        let result = EmojiSidePanelLayout.frames(
            panel: panel,
            variationSize: nil,
            variationTop: 0,
            comparisonSize: comparison,
            visibleFrame: screen,
            spacing: 8
        )
        #expect(result.variation == nil)
        #expect(result.comparison == CGRect(x: 348, y: 552, width: 240, height: 88))
    }
}
