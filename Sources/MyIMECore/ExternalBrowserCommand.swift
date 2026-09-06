import Foundation

public struct ExternalBrowserCommand: Codable, Sendable {
    public let url: URL?
    public let title: String
    public let frameX: Double
    public let frameY: Double
    public let frameWidth: Double
    public let frameHeight: Double
    public let isVisible: Bool
    public let openShortcutDisplayName: String?

    public init(
        url: URL?,
        title: String,
        frameX: Double,
        frameY: Double,
        frameWidth: Double,
        frameHeight: Double,
        isVisible: Bool,
        openShortcutDisplayName: String? = nil
    ) {
        self.url = url
        self.title = title
        self.frameX = frameX
        self.frameY = frameY
        self.frameWidth = frameWidth
        self.frameHeight = frameHeight
        self.isVisible = isVisible
        self.openShortcutDisplayName = openShortcutDisplayName
    }
}
