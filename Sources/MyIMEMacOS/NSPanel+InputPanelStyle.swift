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
        contentView?.wantsLayer = true
        contentView?.layer?.cornerRadius = 0
    }

    func inputPanelRuntimeSnapshot(
        label: String,
        placement: InputPanelPlacement? = nil
    ) -> InputPanelRuntimeSnapshot {
        InputPanelRuntimeSnapshot(
            label: label,
            frameOrigin: frame.origin,
            frameSize: frame.size,
            contentRectSize: contentRect(forFrameRect: frame).size,
            contentViewSize: contentView?.bounds.size ?? .zero,
            backingScaleFactor: backingScaleFactor,
            level: level,
            hasShadow: hasShadow,
            backgroundColor: backgroundColor,
            isOpaque: isOpaque,
            isVisible: isVisible,
            placement: placement
        )
    }
}

struct InputPanelRuntimeSnapshot {
    let label: String
    let frameOrigin: NSPoint
    let frameSize: NSSize
    let contentRectSize: NSSize
    let contentViewSize: NSSize
    let backingScaleFactor: CGFloat
    let level: NSWindow.Level
    let hasShadow: Bool
    let backgroundColor: NSColor
    let isOpaque: Bool
    let isVisible: Bool
    let placement: InputPanelPlacement?

    var report: String {
        var values = [
            "label=\(label)",
            "origin=\(Self.pointDescription(frameOrigin))",
            "frame=\(Self.sizeDescription(frameSize))",
            "contentRect=\(Self.sizeDescription(contentRectSize))",
            "contentView=\(Self.sizeDescription(contentViewSize))",
            "scale=\(backingScaleFactor)",
            "level=\(level.rawValue)",
            "shadow=\(hasShadow ? 1 : 0)",
            "background=\(backgroundColor.description)",
            "opaque=\(isOpaque ? 1 : 0)",
            "visible=\(isVisible ? 1 : 0)"
        ]
        if let placement {
            values += [
                "screen=\(placement.screenIdentifier)",
                "direction=\(placement.direction.rawValue)",
                String(format: "anchorDistance=%.3f", placement.anchorDistance)
            ]
        }
        return values.joined(separator: " ")
    }

    private static func sizeDescription(_ size: NSSize) -> String {
        String(format: "%.3fx%.3f", size.width, size.height)
    }

    private static func pointDescription(_ point: NSPoint) -> String {
        String(format: "%.3f,%.3f", point.x, point.y)
    }
}
