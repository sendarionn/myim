import CoreGraphics
import Testing
@testable import MyIMECore

@Suite
struct EmojiSidePanelLayoutTests {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let comparison = CGSize(width: 240, height: 88)

    private func frames(
        panelX: CGFloat,
        variation: CGSize? = CGSize(width: 240, height: 52),
        keepsColumn: Bool = false,
        preferredSide: EmojiSidePanelLayout.Side? = nil,
        screen: CGRect? = nil
    ) -> (CGRect, EmojiSidePanelLayout.Frames) {
        let panel = CGRect(x: panelX, y: 400, width: 240, height: 240)
        return (panel, EmojiSidePanelLayout.frames(
            panel: panel,
            variationSize: variation,
            variationTop: 560,
            variationColumnWidth: 240,
            keepsVariationColumn: keepsColumn,
            comparisonSize: comparison,
            preferredSide: preferredSide,
            visibleFrame: screen ?? self.screen,
            spacing: 8
        ))
    }

    private func expectApart(
        _ panel: CGRect,
        _ result: EmojiSidePanelLayout.Frames,
        in screen: CGRect
    ) {
        let frames = [result.variation, result.comparison].compactMap { $0 }
        for frame in frames {
            #expect(!frame.intersects(panel))
            #expect(screen.contains(frame))
        }
        if let variation = result.variation, let comparison = result.comparison {
            #expect(!variation.intersects(comparison))
        }
    }

    /// The variations beside the panel at their emoji, the comparison
    /// outside them at the panel's top
    @Test
    func variationsComeBetweenThePanelAndTheComparison() {
        let (panel, result) = frames(panelX: 100)
        expectApart(panel, result, in: screen)
        #expect(result.variation == CGRect(x: 348, y: 508, width: 240, height: 52))
        #expect(result.comparison == CGRect(x: 596, y: 552, width: 240, height: 88))
        #expect(result.side == .right)
    }

    /// Fewer variations do not pull the comparison in, and while the
    /// variations are about to show it already waits outside them
    @Test
    func theComparisonDoesNotFollowTheVariationsWidth() {
        let (_, wide) = frames(panelX: 100)
        let (_, narrow) = frames(panelX: 100, variation: CGSize(width: 80, height: 52))
        let (_, waiting) = frames(panelX: 100, variation: nil, keepsColumn: true)
        #expect(wide.comparison == narrow.comparison)
        #expect(wide.comparison == waiting.comparison)
    }

    @Test
    func withoutVariationsTheComparisonSitsBesideThePanel() {
        let (_, result) = frames(panelX: 100, variation: nil)
        #expect(result.variation == nil)
        #expect(result.comparison == CGRect(x: 348, y: 552, width: 240, height: 88))
    }

    @Test
    func atTheRightEdgeTheyGoLeft() {
        let (panel, result) = frames(panelX: 1190)
        expectApart(panel, result, in: screen)
        #expect(result.variation!.maxX == panel.minX - 8)
        #expect(result.comparison!.maxX == panel.minX - 8 - 240 - 8)
        #expect(result.side == .left)
    }

    /// The side used last is kept while it fits
    @Test
    func theSideUsedLastIsKept() {
        let (panel, result) = frames(panelX: 700, preferredSide: .left)
        expectApart(panel, result, in: screen)
        #expect(result.side == .left)
    }

    /// Without room for a row on either side, each goes beside the panel
    /// on its own side
    @Test
    func withoutRoomForARowTheySplit() {
        let narrow = CGRect(x: 0, y: 0, width: 760, height: 900)
        let (panel, result) = frames(panelX: 260, screen: narrow)
        expectApart(panel, result, in: narrow)
        #expect(result.variation!.minX == panel.maxX + 8)
        #expect(result.comparison!.maxX == panel.minX - 8)
    }

    /// Near the right edge the comparison alone already goes left, where
    /// the variations will also fit, rather than changing sides later
    @Test
    func theComparisonAloneTakesTheSideTheRowFitsOn() {
        let (panel, alone) = frames(panelX: 960, variation: nil)
        let (_, row) = frames(panelX: 960)
        #expect(alone.comparison!.maxX == panel.minX - 8)
        #expect(alone.side == .left)
        #expect(row.side == .left)
    }
}
