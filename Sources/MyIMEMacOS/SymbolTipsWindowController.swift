@preconcurrency import AppKit
import MyIMECore

final class SymbolTipsWindowController {
    private static let spacing: CGFloat = 8
    private let panel: NSPanel
    private let text = NSTextField(wrappingLabelWithString: "")

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 62),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.backgroundColor = .windowBackgroundColor
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .popUpMenu
        panel.isOpaque = true
        panel.isReleasedWhenClosed = false
        text.font = .systemFont(ofSize: 13)
        text.frame = NSRect(x: 10, y: 8, width: 300, height: 46)
        panel.contentView = NSView(frame: panel.contentRect(forFrameRect: panel.frame))
        panel.contentView?.addSubview(text)
    }

    var visibleFrame: NSRect? { panel.isVisible ? panel.frame : nil }

    func show(_ tips: SymbolTips, beside anchor: NSRect) {
        text.stringValue = [
            "\(tips.character)　\(tips.codePoint)",
            tips.unicodeName
        ].joined(separator: "\n")
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) }
            ?? NSScreen.main
        let visible = screen?.visibleFrame ?? anchor
        let size = panel.frame.size
        let right = anchor.maxX + Self.spacing
        let left = anchor.minX - size.width - Self.spacing
        let x = right + size.width <= visible.maxX ? right : left
        panel.setFrameOrigin(NSPoint(
            x: min(max(x, visible.minX), visible.maxX - size.width),
            y: min(max(anchor.maxY - size.height, visible.minY), visible.maxY - size.height)
        ))
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }
}
