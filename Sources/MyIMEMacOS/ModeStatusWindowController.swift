@preconcurrency import AppKit

final class ModeStatusWindowController: NSObject {
    private static let horizontalPadding: CGFloat = 14
    private static let verticalPadding: CGFloat = 9
    private static let anchorSpacing: CGFloat = 8

    private let panel: NSPanel
    private let label: NSTextField
    private var dismissWorkItem: DispatchWorkItem?

    override init() {
        label = NSTextField(labelWithString: "")
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 36),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        super.init()

        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        label.alignment = .center
        label.lineBreakMode = .byClipping

        let contentView = NSView()
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 8
        contentView.layer?.masksToBounds = true
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

    func show(enabled: Bool, near anchorFrame: NSRect) {
        dismissWorkItem?.cancel()

        label.stringValue = enabled ? "翻訳モード  ON" : "翻訳モード  OFF"
        label.textColor = enabled ? .alternateSelectedControlTextColor : .labelColor
        panel.contentView?.layer?.backgroundColor = (
            enabled ? NSColor.controlAccentColor : NSColor.windowBackgroundColor
        ).cgColor

        let textSize = label.intrinsicContentSize
        let panelSize = NSSize(
            width: ceil(textSize.width) + Self.horizontalPadding * 2,
            height: ceil(textSize.height) + Self.verticalPadding * 2
        )
        panel.setContentSize(panelSize)
        label.frame = NSRect(
            x: Self.horizontalPadding,
            y: Self.verticalPadding,
            width: ceil(textSize.width),
            height: ceil(textSize.height)
        )

        let resolvedAnchor = anchorFrame == .zero
            ? NSRect(origin: NSEvent.mouseLocation, size: .zero)
            : anchorFrame
        let screen = NSScreen.screens.first {
            $0.frame.contains(resolvedAnchor.origin)
        } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let preferredY = resolvedAnchor.minY - panelSize.height - Self.anchorSpacing
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

        let workItem = DispatchWorkItem { [weak self] in
            self?.panel.orderOut(nil)
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: workItem)
    }

    func hide() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        panel.orderOut(nil)
    }
}
