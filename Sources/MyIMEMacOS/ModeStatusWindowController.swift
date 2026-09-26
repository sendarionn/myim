@preconcurrency import AppKit

private final class VerticallyCenteredTextFieldCell: NSTextFieldCell {
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        var drawingRect = super.drawingRect(forBounds: rect)
        let textHeight = cellSize(forBounds: rect).height
        guard textHeight < rect.height else { return drawingRect }
        drawingRect.origin.y = floor(rect.midY - textHeight / 2)
        drawingRect.size.height = textHeight
        return drawingRect
    }
}

final class ModeStatusWindowController: NSObject {
    private static let horizontalPadding: CGFloat = 14
    private static let verticalPadding: CGFloat = 9
    private static let anchorSpacing: CGFloat = 8

    private let panel: NSPanel
    private let label: NSTextField

    override init() {
        label = NSTextField(labelWithString: "")
        panel = PassiveInputPanel(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 36),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        super.init()

        panel.animationBehavior = .none
        panel.becomesKeyOnlyIfNeeded = true
        label.cell = VerticallyCenteredTextFieldCell(textCell: "")
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        label.alignment = .center
        label.lineBreakMode = .byClipping
        label.maximumNumberOfLines = 1

        let contentView = NSView()
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 0
        contentView.layer?.masksToBounds = true
        contentView.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        contentView.addSubview(label)
        panel.contentView = contentView
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.isOpaque = false
        panel.isReleasedWhenClosed = false
        panel.level = .popUpMenu
    }

    func show(title: String, near anchorFrame: NSRect) {
        label.stringValue = title
        label.textColor = .alternateSelectedControlTextColor

        let textSize = label.intrinsicContentSize
        let panelSize = NSSize(
            width: ceil(textSize.width) + Self.horizontalPadding * 2,
            height: ceil(textSize.height) + Self.verticalPadding * 2
        )
        panel.setContentSize(panelSize)
        label.frame = NSRect(
            origin: .zero,
            size: panelSize
        )
        label.autoresizingMask = [.width, .height]

        let resolvedAnchor = anchorFrame == .zero
            ? NSRect(origin: NSEvent.mouseLocation, size: .zero)
            : anchorFrame
        let screen = NSScreen.screens.first {
            $0.frame.contains(resolvedAnchor.origin)
        } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let preferredY = resolvedAnchor.minY
            - panelSize.height
            - Self.anchorSpacing
        let fallbackY = resolvedAnchor.maxY + Self.anchorSpacing
        panel.setFrameOrigin(NSPoint(
            x: min(
                max(resolvedAnchor.minX, visibleFrame.minX),
                visibleFrame.maxX - panelSize.width
            ),
            y: preferredY >= visibleFrame.minY
                ? preferredY
                : min(fallbackY, visibleFrame.maxY - panelSize.height)
        ))
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }
}
