import Foundation

public enum CandidateRowWidth {
    public static func resolve(
        textWidth: CGFloat,
        accessoryWidth: CGFloat,
        horizontalPadding: CGFloat,
        minimumWidth: CGFloat,
        maximumTextWidth: CGFloat,
        maximumPanelWidth: CGFloat
    ) -> CGFloat {
        let textContainerWidth = min(
            max(
                textWidth + horizontalPadding * 2,
                minimumWidth
            ),
            maximumTextWidth
        )
        return min(
            textContainerWidth + max(accessoryWidth, 0),
            maximumPanelWidth
        )
    }
}

/// A caption fits its text but never reaches beyond its panel, which
/// widens for a longer caption so it does not cover a neighbouring panel
public enum CaptionedPanelWidth {
    public static func resolve(
        contentWidth: Double,
        captionWidth: Double,
        maximumWidth: Double
    ) -> (panel: Double, caption: Double) {
        let panel = min(max(contentWidth, captionWidth), maximumWidth)
        return (panel, min(captionWidth, panel))
    }
}
