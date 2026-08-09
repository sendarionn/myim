@preconcurrency import AppKit
import MyIMECore

final class FuzzySuggestionWindowController {
    private static let spacing: CGFloat = 6
    private let panel: NSPanel
    private let stackView: NSStackView

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 4
        stackView.edgeInsets = NSEdgeInsets(
            top: 8,
            left: 10,
            bottom: 8,
            right: 10
        )
        panel.contentView = stackView
        panel.backgroundColor = .windowBackgroundColor
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .popUpMenu
        panel.isOpaque = true
        panel.isReleasedWhenClosed = false
    }

    func show(matches: [FuzzyConversionMatch], near anchorFrame: NSRect) {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let title = NSTextField(labelWithString: "もしかして？")
        title.font = .systemFont(ofSize: 12, weight: .semibold)
        title.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(title)

        for match in matches.prefix(3) {
            let values = match.candidates.prefix(2).joined(separator: "・")
            let label = NSTextField(
                labelWithString: "\(values)  [\(match.reading)]"
            )
            label.font = .systemFont(ofSize: 13)
            label.lineBreakMode = .byTruncatingTail
            stackView.addArrangedSubview(label)
        }

        stackView.layoutSubtreeIfNeeded()
        let fittingSize = stackView.fittingSize
        let size = NSSize(
            width: min(max(fittingSize.width, 180), 420),
            height: fittingSize.height
        )
        panel.setContentSize(size)

        let screen = NSScreen.screens.first {
            $0.frame.intersects(anchorFrame)
        } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? anchorFrame
        let belowY = anchorFrame.minY - panel.frame.height - Self.spacing
        let aboveY = anchorFrame.maxY + Self.spacing
        let y = belowY >= visibleFrame.minY ? belowY : aboveY
        let x = min(
            max(anchorFrame.minX, visibleFrame.minX),
            max(visibleFrame.minX, visibleFrame.maxX - panel.frame.width)
        )
        panel.setFrameOrigin(NSPoint(
            x: x,
            y: min(max(y, visibleFrame.minY), visibleFrame.maxY - panel.frame.height)
        ))
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }
}
