import Testing
@testable import MyIMECore

@Suite
struct CaptionedPanelWidthTests {
    @Test
    func captionNeverReachesBeyondANarrowPanel() {
        // 「姐妹」 with 「中国語（簡体字）」 underneath
        let width = CaptionedPanelWidth.resolve(
            contentWidth: 60,
            captionWidth: 110,
            maximumWidth: 360
        )

        #expect(width.panel == 110)
        #expect(width.caption == width.panel)
    }

    @Test
    func shortCaptionKeepsItsOwnWidthUnderAWiderPanel() {
        // 「英語」 under 「affection」
        let width = CaptionedPanelWidth.resolve(
            contentWidth: 150,
            captionWidth: 50,
            maximumWidth: 360
        )

        #expect(width.panel == 150)
        #expect(width.caption == 50)
    }

    @Test
    func widthStaysWithinTheMaximum() {
        let width = CaptionedPanelWidth.resolve(
            contentWidth: 60,
            captionWidth: 500,
            maximumWidth: 360
        )

        #expect(width.panel == 360)
        #expect(width.caption == 360)
    }
}
