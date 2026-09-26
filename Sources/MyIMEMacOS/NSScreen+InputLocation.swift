@preconcurrency import AppKit

extension NSScreen {
    static func inputScreen(containing frame: NSRect) -> NSScreen? {
        screens.first { $0.frame.intersects(frame) }
            ?? screens.first { $0.frame.contains(frame.origin) }
            ?? main
    }
}
