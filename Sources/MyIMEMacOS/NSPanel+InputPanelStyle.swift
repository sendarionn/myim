@preconcurrency import AppKit

extension NSPanel {
    func applyInputPanelStyle(
        backgroundColor: NSColor = .windowBackgroundColor,
        isOpaque: Bool = true,
        hasShadow: Bool = true
    ) {
        animationBehavior = .none
        self.backgroundColor = backgroundColor
        self.hasShadow = hasShadow
        hidesOnDeactivate = false
        level = .popUpMenu
        self.isOpaque = isOpaque
        isReleasedWhenClosed = false
    }

    func inputPanelRuntimeSnapshot(label: String) -> InputPanelRuntimeSnapshot {
        InputPanelRuntimeSnapshot(
            label: label,
            frameSize: frame.size,
            contentRectSize: contentRect(forFrameRect: frame).size,
            contentViewSize: contentView?.bounds.size ?? .zero,
            backingScaleFactor: backingScaleFactor,
            level: level,
            hasShadow: hasShadow,
            backgroundColor: backgroundColor,
            isOpaque: isOpaque,
            isVisible: isVisible
        )
    }
}

struct InputPanelRuntimeSnapshot {
    let label: String
    let frameSize: NSSize
    let contentRectSize: NSSize
    let contentViewSize: NSSize
    let backingScaleFactor: CGFloat
    let level: NSWindow.Level
    let hasShadow: Bool
    let backgroundColor: NSColor
    let isOpaque: Bool
    let isVisible: Bool

    var report: String {
        [
            "label=\(label)",
            "frame=\(Self.sizeDescription(frameSize))",
            "contentRect=\(Self.sizeDescription(contentRectSize))",
            "contentView=\(Self.sizeDescription(contentViewSize))",
            "scale=\(backingScaleFactor)",
            "level=\(level.rawValue)",
            "shadow=\(hasShadow ? 1 : 0)",
            "background=\(backgroundColor.description)",
            "opaque=\(isOpaque ? 1 : 0)",
            "visible=\(isVisible ? 1 : 0)"
        ].joined(separator: " ")
    }

    private static func sizeDescription(_ size: NSSize) -> String {
        String(format: "%.3fx%.3f", size.width, size.height)
    }
}
