@preconcurrency import AppKit

struct FuzzySuggestion: Equatable {
    let candidate: String
    let reading: String
    let distance: Int

    init(
        candidate: String,
        reading: String,
        distance: Int
    ) {
        self.candidate = candidate
        self.reading = reading
        self.distance = distance
    }
}

final class FuzzySuggestionWindowController {
    private static let spacing: CGFloat = 6
    private static let guideSpacing: CGFloat = 4
    private static let itemHeight = CandidatePanelItemStyle.height
    private static let minimumItemWidth: CGFloat = 32
    private static let maximumItemWidth: CGFloat = 240
    private static let maximumPanelWidth: CGFloat = 360
    private static let itemSpacing: CGFloat = 2
    private static let maximumVisibleSuggestionCount = 4
    private let panel: NSPanel
    private let guidePanel: NSPanel
    private let stackView: NSStackView
    private let guideLabel: NSTextField

    var visibleFrame: NSRect? {
        guard panel.isVisible else { return nil }
        return guidePanel.isVisible
            ? panel.frame.union(guidePanel.frame)
            : panel.frame
    }

    var isVisible: Bool { panel.isVisible }

    init() {
        panel = PassiveInputPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        guidePanel = PassiveInputPanel(
            contentRect: NSRect(x: 0, y: 0, width: 180, height: 24),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        stackView = NSStackView()
        guideLabel = NSTextField(labelWithString: "")
        panel.animationBehavior = .none
        guidePanel.animationBehavior = .none
        panel.becomesKeyOnlyIfNeeded = true
        guidePanel.becomesKeyOnlyIfNeeded = true
        stackView.wantsLayer = true
        stackView.layer?.cornerRadius = 0
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = Self.itemSpacing
        stackView.edgeInsets = NSEdgeInsets(
            top: 0,
            left: 0,
            bottom: 0,
            right: 0
        )
        panel.contentView = stackView
        panel.backgroundColor = .windowBackgroundColor
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .popUpMenu
        panel.isOpaque = true
        panel.isReleasedWhenClosed = false

        guideLabel.font = PanelShortcutGuideStyle.font
        guideLabel.textColor = PanelShortcutGuideStyle.color
        guideLabel.lineBreakMode = .byClipping
        let guideContentView = NSView()
        guideContentView.addSubview(guideLabel)
        guidePanel.contentView = guideContentView
        guidePanel.backgroundColor = .windowBackgroundColor
        guidePanel.hasShadow = true
        guidePanel.hidesOnDeactivate = false
        guidePanel.level = .popUpMenu
        guidePanel.isOpaque = true
        guidePanel.isReleasedWhenClosed = false
    }

    func show(
        suggestions: [FuzzySuggestion],
        selectedIndex: Int?,
        near anchorFrame: NSRect,
        avoidingFrames: [NSRect] = [],
        isAccented: Bool = false
    ) {
        stackView.layer?.borderWidth = isAccented ? 2 : 0
        stackView.layer?.borderColor = isAccented
            ? NSColor.controlAccentColor.cgColor
            : NSColor.clear.cgColor
        let screen = NSScreen.screens.first {
            $0.frame.intersects(anchorFrame)
        } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? anchorFrame
        let visibleSuggestions = Array(
            suggestions.prefix(Self.maximumVisibleSuggestionCount)
        )

        let itemWidths = visibleSuggestions.map(itemWidth)
        let availableWidth = min(
            Self.maximumPanelWidth - stackView.edgeInsets.left
                - stackView.edgeInsets.right,
            visibleFrame.width
        )
        let targetWidth = min(
            packedTargetWidth(
                itemWidths: itemWidths,
                availableWidth: availableWidth
            ),
            availableWidth
        )
        updateSuggestionRows(
            visibleSuggestions,
            width: targetWidth,
            selectedIndex: selectedIndex
        )

        stackView.layoutSubtreeIfNeeded()
        let fittingSize = stackView.fittingSize
        panel.setContentSize(NSSize(
            width: min(fittingSize.width, Self.maximumPanelWidth),
            height: fittingSize.height
        ))

        positionPanels(
            near: anchorFrame,
            visibleFrame: visibleFrame,
            hasGuide: false,
            avoidingFrames: avoidingFrames
        )
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
        guidePanel.orderOut(nil)
    }

    private func itemWidth(for suggestion: FuzzySuggestion) -> CGFloat {
        let text = suggestion.candidate
        let textWidth = ceil((text as NSString).size(
            withAttributes: [.font: CandidatePanelItemStyle.font]
        ).width)
        return min(
            max(
                textWidth + CandidatePanelItemStyle.horizontalPadding * 2,
                Self.minimumItemWidth
            ),
            Self.maximumItemWidth
        )
    }

    private func packedTargetWidth(
        itemWidths: [CGFloat],
        availableWidth: CGFloat
    ) -> CGFloat {
        guard !itemWidths.isEmpty else { return Self.minimumItemWidth }
        return min(
            availableWidth,
            itemWidths.max() ?? Self.minimumItemWidth
        )
    }

    private func updateSuggestionRows(
        _ suggestions: [FuzzySuggestion],
        width: CGFloat,
        selectedIndex: Int?
    ) {
        while stackView.arrangedSubviews.count > suggestions.count {
            guard let last = stackView.arrangedSubviews.last else { break }
            stackView.removeArrangedSubview(last)
            last.removeFromSuperview()
        }
        while stackView.arrangedSubviews.count < suggestions.count {
            stackView.addArrangedSubview(CandidatePanelRowView(frame: .zero))
        }
        for (index, suggestion) in suggestions.enumerated() {
            guard let row = stackView.arrangedSubviews[index]
                as? CandidatePanelRowView else { continue }
            row.setFixedSize(width: width, height: Self.itemHeight)
            row.configure(
                text: suggestion.candidate,
                isSelected: index == selectedIndex
            )
        }
    }

    func hide() {
        panel.orderOut(nil)
        guidePanel.orderOut(nil)
    }

    func reposition(
        near anchorFrame: NSRect,
        avoidingFrames: [NSRect] = []
    ) {
        guard panel.isVisible else { return }
        let screen = NSScreen.screens.first {
            $0.frame.intersects(anchorFrame)
        } ?? NSScreen.main
        positionPanels(
            near: anchorFrame,
            visibleFrame: screen?.visibleFrame ?? anchorFrame,
            hasGuide: guidePanel.isVisible,
            avoidingFrames: avoidingFrames
        )
    }

    private func positionPanels(
        near anchorFrame: NSRect,
        visibleFrame: NSRect,
        hasGuide: Bool,
        avoidingFrames: [NSRect]
    ) {
        let rightX = anchorFrame.maxX + Self.spacing
        let leftX = anchorFrame.minX - Self.spacing - panel.frame.width
        let rightSpace = max(visibleFrame.maxX - rightX, 0)
        let leftSpace = max(anchorFrame.minX - Self.spacing - visibleFrame.minX, 0)
        let panelX: CGFloat
        if rightX + panel.frame.width <= visibleFrame.maxX {
            panelX = rightX
        } else if leftX >= visibleFrame.minX {
            panelX = leftX
        } else if rightSpace >= leftSpace {
            panel.setFrame(
                NSRect(
                    x: rightX,
                    y: panel.frame.minY,
                    width: rightSpace,
                    height: panel.frame.height
                ),
                display: false
            )
            panelX = rightX
        } else {
            panel.setFrame(
                NSRect(
                    x: visibleFrame.minX,
                    y: panel.frame.minY,
                    width: leftSpace,
                    height: panel.frame.height
                ),
                display: false
            )
            panelX = visibleFrame.minX
        }
        let alignedPanelY = min(
            max(anchorFrame.maxY - panel.frame.height, visibleFrame.minY),
            visibleFrame.maxY - panel.frame.height
        )
        let panelY = nonOverlappingY(
            preferredY: alignedPanelY,
            panelX: panelX,
            visibleFrame: visibleFrame,
            avoidingFrames: avoidingFrames
        )
        panel.setFrameOrigin(NSPoint(
            x: panelX,
            y: panelY
        ))
        guard hasGuide else { return }
        guidePanel.setFrameOrigin(guideOrigin(
            visibleFrame: visibleFrame,
            avoidingFrames: [panel.frame] + avoidingFrames
        ))
    }

    private func guideOrigin(
        visibleFrame: NSRect,
        avoidingFrames: [NSRect]
    ) -> NSPoint {
        let size = guidePanel.frame.size
        let alignedX = min(
            max(panel.frame.minX, visibleFrame.minX),
            visibleFrame.maxX - size.width
        )
        let preferred = NSPoint(
            x: alignedX,
            y: panel.frame.minY - Self.guideSpacing - size.height
        )
        let rawCandidates = [preferred]
            + avoidingFrames.flatMap { avoided in
                [
                    NSPoint(
                        x: alignedX,
                        y: avoided.minY - Self.guideSpacing - size.height
                    ),
                    NSPoint(
                        x: alignedX,
                        y: avoided.maxY + Self.guideSpacing
                    ),
                    NSPoint(
                        x: avoided.minX - Self.guideSpacing - size.width,
                        y: panel.frame.minY
                    ),
                    NSPoint(
                        x: avoided.maxX + Self.guideSpacing,
                        y: panel.frame.minY
                    )
                ]
            }
        let candidates = rawCandidates.filter { origin in
            visibleFrame.contains(NSRect(origin: origin, size: size))
        }
        let ranked = candidates.sorted { lhs, rhs in
            let lhsFrame = NSRect(origin: lhs, size: size)
            let rhsFrame = NSRect(origin: rhs, size: size)
            let lhsOverlap = overlapArea(
                frame: lhsFrame,
                avoidingFrames: avoidingFrames
            )
            let rhsOverlap = overlapArea(
                frame: rhsFrame,
                avoidingFrames: avoidingFrames
            )
            if lhsOverlap != rhsOverlap { return lhsOverlap < rhsOverlap }
            return hypot(lhs.x - preferred.x, lhs.y - preferred.y)
                < hypot(rhs.x - preferred.x, rhs.y - preferred.y)
        }
        if let origin = ranked.first { return origin }
        return NSPoint(
            x: min(max(preferred.x, visibleFrame.minX), visibleFrame.maxX - size.width),
            y: min(max(preferred.y, visibleFrame.minY), visibleFrame.maxY - size.height)
        )
    }

    private func overlapArea(
        frame: NSRect,
        avoidingFrames: [NSRect]
    ) -> CGFloat {
        avoidingFrames.reduce(0) { result, avoided in
            let intersection = frame.intersection(avoided)
            return result + max(intersection.width, 0)
                * max(intersection.height, 0)
        }
    }

    private func nonOverlappingY(
        preferredY: CGFloat,
        panelX: CGFloat,
        visibleFrame: NSRect,
        avoidingFrames: [NSRect]
    ) -> CGFloat {
        let size = panel.frame.size
        let preferredFrame = NSRect(
            x: panelX,
            y: preferredY,
            width: size.width,
            height: size.height
        )
        guard avoidingFrames.contains(where: preferredFrame.intersects) else {
            return preferredY
        }
        let candidates = avoidingFrames.flatMap { avoided in
            [
                avoided.maxY + Self.guideSpacing,
                avoided.minY - Self.guideSpacing - size.height
            ]
        }.filter { y in
            y >= visibleFrame.minY
                && y + size.height <= visibleFrame.maxY
        }
        return candidates.min { lhs, rhs in
            let lhsFrame = NSRect(
                x: panelX,
                y: lhs,
                width: size.width,
                height: size.height
            )
            let rhsFrame = NSRect(
                x: panelX,
                y: rhs,
                width: size.width,
                height: size.height
            )
            let lhsOverlap = avoidingFrames.filter(lhsFrame.intersects).count
            let rhsOverlap = avoidingFrames.filter(rhsFrame.intersects).count
            return lhsOverlap == rhsOverlap
                ? abs(lhs - preferredY) < abs(rhs - preferredY)
                : lhsOverlap < rhsOverlap
        } ?? preferredY
    }
}
