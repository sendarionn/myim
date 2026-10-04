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
