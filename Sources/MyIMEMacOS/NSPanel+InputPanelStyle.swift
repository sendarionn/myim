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
}
