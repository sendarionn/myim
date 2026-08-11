@preconcurrency import AppKit

enum FuzzySuggestionKind: Equatable {
    case spelling
    case semantic
}

struct FuzzySuggestion: Equatable {
    let candidate: String
    let reading: String
    let distance: Int
    let kind: FuzzySuggestionKind

    init(
        candidate: String,
        reading: String,
        distance: Int,
        kind: FuzzySuggestionKind = .spelling
    ) {
        self.candidate = candidate
        self.reading = reading
        self.distance = distance
        self.kind = kind
    }
}

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
        stackView.spacing = 3
        stackView.edgeInsets = NSEdgeInsets(
            top: 8,
            left: 8,
            bottom: 8,
            right: 8
        )
        panel.contentView = stackView
        panel.backgroundColor = .windowBackgroundColor
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .popUpMenu
        panel.isOpaque = true
        panel.isReleasedWhenClosed = false
    }

    func show(
        suggestions: [FuzzySuggestion],
        selectedIndex: Int?,
        near anchorFrame: NSRect
    ) {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let title = NSTextField(labelWithString: "もしかして？")
        title.font = .systemFont(ofSize: 12, weight: .semibold)
        title.textColor = .secondaryLabelColor
        let guide = NSTextField(labelWithString: selectedIndex == nil
            ? "⇧Tab 選択"
            : "矢印 移動　Return 確定　Esc 戻る")
        guide.font = PanelShortcutGuideStyle.font
        guide.textColor = PanelShortcutGuideStyle.color
        let header = NSStackView(views: [title, guide])
        header.orientation = .horizontal
        header.alignment = .firstBaseline
        header.spacing = 7
        stackView.addArrangedSubview(header)

        for (index, suggestion) in suggestions.enumerated() {
            let row = NSView()
            row.wantsLayer = true
            row.layer?.cornerRadius = 5
            row.layer?.backgroundColor = index == selectedIndex
                ? NSColor.controlAccentColor.cgColor
                : NSColor.clear.cgColor
            let label = NSTextField(
                labelWithString: "\(suggestion.candidate)  [\(suggestion.reading)]"
            )
            label.font = .systemFont(ofSize: 13)
            label.textColor = index == selectedIndex
                ? .alternateSelectedControlTextColor
                : .labelColor
            label.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 6),
                label.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -6),
                label.topAnchor.constraint(equalTo: row.topAnchor, constant: 4),
                label.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -4)
            ])
            stackView.addArrangedSubview(row)
            row.widthAnchor.constraint(
                greaterThanOrEqualToConstant: 164
            ).isActive = true
        }

        stackView.layoutSubtreeIfNeeded()
        let fittingSize = stackView.fittingSize
        panel.setContentSize(NSSize(
            width: min(max(fittingSize.width, 180), 420),
            height: fittingSize.height
        ))

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
