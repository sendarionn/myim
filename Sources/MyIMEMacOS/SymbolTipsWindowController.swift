@preconcurrency import AppKit
import MyIMECore

final class SymbolTipsWindowController {
    private static let spacing: CGFloat = 8
    private static let horizontalPadding: CGFloat = 8
    private static let verticalPadding: CGFloat = 5
    private static let minimumWidth: CGFloat = 130
    private static let maximumWidth: CGFloat = 240
    private let panel: NSPanel
    private let text = NSTextField(wrappingLabelWithString: "")

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 180, height: 42),
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
        text.font = .systemFont(ofSize: 12)
        text.maximumNumberOfLines = 3
        text.lineBreakMode = .byWordWrapping
        text.frame = NSRect(x: 8, y: 5, width: 164, height: 32)
        panel.contentView = NSView(frame: panel.contentRect(forFrameRect: panel.frame))
        panel.contentView?.addSubview(text)
    }

    var visibleFrame: NSRect? { panel.isVisible ? panel.frame : nil }

    func show(_ tips: SymbolTips, beside anchor: NSRect) {
        text.stringValue = [
            "\(tips.character)　\(tips.codePoint)",
            tips.unicodeName
        ].joined(separator: "\n")
        resizePanelToFitText()
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) }
            ?? NSScreen.main
        let visible = screen?.visibleFrame ?? anchor
        let size = panel.frame.size
        let above = anchor.maxY + Self.spacing
        let below = anchor.minY - Self.spacing - size.height
        let y = above + size.height <= visible.maxY ? above : below
        panel.setFrameOrigin(NSPoint(
            x: min(
                max(anchor.minX, visible.minX),
                visible.maxX - size.width
            ),
            y: min(max(y, visible.minY), visible.maxY - size.height)
        ))
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func resizePanelToFitText() {
        let font = text.font ?? .systemFont(ofSize: 12)
        let lines = text.stringValue.components(separatedBy: .newlines)
        let measuredWidth = lines.map {
            ceil(($0 as NSString).size(withAttributes: [.font: font]).width)
        }.max() ?? 0
        let panelWidth = min(
            max(
                measuredWidth + Self.horizontalPadding * 2,
                Self.minimumWidth
            ),
            Self.maximumWidth
        )
        let contentWidth = panelWidth - Self.horizontalPadding * 2
        let textBounds = (text.stringValue as NSString).boundingRect(
            with: NSSize(width: contentWidth, height: 1_000),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        let contentHeight = min(max(ceil(textBounds.height), 30), 54)
        let panelHeight = contentHeight + Self.verticalPadding * 2
        panel.setContentSize(NSSize(width: panelWidth, height: panelHeight))
        text.frame = NSRect(
            x: Self.horizontalPadding,
            y: Self.verticalPadding,
            width: contentWidth,
            height: contentHeight
        )
    }
}
