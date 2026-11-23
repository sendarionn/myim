@preconcurrency import AppKit

enum InputPanelVerticalPlacement: String {
    case below
    case above
}

struct InputPanelScreenGeometry {
    let identifier: String
    let frame: NSRect
    let visibleFrame: NSRect
}

struct InputPanelPlacement {
    let frame: NSRect
    let direction: InputPanelVerticalPlacement
    let screenIdentifier: String
    let anchorFrame: NSRect

    var anchorDistance: CGFloat {
        switch direction {
        case .below:
            max(anchorFrame.minY - frame.maxY, 0)
        case .above:
            max(frame.minY - anchorFrame.maxY, 0)
        }
    }
}

struct InputPanelPlacementCase {
    let label: String
    let anchorFrame: NSRect
    let screens: [InputPanelScreenGeometry]
    let avoidedFrames: [NSRect]
    let fallbackPoint: NSPoint

    func relabeled(_ label: String) -> Self {
        Self(
            label: label,
            anchorFrame: anchorFrame,
            screens: screens,
            avoidedFrames: avoidedFrames,
            fallbackPoint: fallbackPoint
        )
    }
}

enum InputPanelPositioning {
    static let panelSize = NSSize(width: 240, height: 240)
    static let outerPadding: CGFloat = 8
    static let anchorSpacing: CGFloat = 8

    static func placement(
        anchorFrame: NSRect,
        avoidedFrames: [NSRect] = [],
        panelSize: NSSize = panelSize
    ) -> InputPanelPlacement {
        placement(
            anchorFrame: anchorFrame,
            screens: NSScreen.screens.map(screenGeometry),
            avoidedFrames: avoidedFrames,
            fallbackPoint: NSEvent.mouseLocation,
            panelSize: panelSize
        )
    }

    static func placement(
        anchorFrame: NSRect,
        screens: [InputPanelScreenGeometry],
        avoidedFrames: [NSRect] = [],
        fallbackPoint: NSPoint,
        panelSize: NSSize = panelSize
    ) -> InputPanelPlacement {
        let anchor = resolvedAnchor(anchorFrame, fallbackPoint: fallbackPoint)
        let availableScreens = screens.isEmpty
            ? [InputPanelScreenGeometry(
                identifier: "fallback",
                frame: NSRect(x: 0, y: 0, width: 800, height: 600),
                visibleFrame: NSRect(x: 0, y: 0, width: 800, height: 600)
            )]
            : screens
        let screen = targetScreen(for: anchor, screens: availableScreens)
            ?? availableScreens[0]
        let visible = screen.visibleFrame
        let belowOrigin = NSPoint(
            x: anchor.minX,
            y: anchor.minY - panelSize.height - anchorSpacing
        )
        let aboveOrigin = NSPoint(
            x: anchor.minX,
            y: anchor.maxY + anchorSpacing
        )
        let preferredDirection: InputPanelVerticalPlacement =
            belowOrigin.y >= visible.minY ? .below : .above
        let preferredOrigin = preferredDirection == .below
            ? belowOrigin
            : aboveOrigin
        let oppositeDirection: InputPanelVerticalPlacement =
            preferredDirection == .below ? .above : .below
        let oppositeOrigin = oppositeDirection == .below
            ? belowOrigin
            : aboveOrigin

        var candidates: [(NSPoint, InputPanelVerticalPlacement)] = [
            (preferredOrigin, preferredDirection),
            (oppositeOrigin, oppositeDirection)
        ]
        if !avoidedFrames.isEmpty {
            let occupied = avoidedFrames.reduce(anchor) { $0.union($1) }
            candidates += [
                (
                    NSPoint(
                        x: occupied.maxX + anchorSpacing,
                        y: preferredOrigin.y
                    ),
                    preferredDirection
                ),
                (
                    NSPoint(
                        x: occupied.minX - panelSize.width - anchorSpacing,
                        y: preferredOrigin.y
                    ),
                    preferredDirection
                ),
                (
                    NSPoint(
                        x: preferredOrigin.x,
                        y: occupied.maxY + anchorSpacing
                    ),
                    .above
                ),
                (
                    NSPoint(
                        x: preferredOrigin.x,
                        y: occupied.minY - panelSize.height - anchorSpacing
                    ),
                    .below
                )
            ]
        }

        let placements = candidates.map { origin, direction in
            let frame = NSRect(
                origin: clampedOrigin(
                    origin,
                    panelSize: panelSize,
                    visibleFrame: visible
                ),
                size: panelSize
            )
            return InputPanelPlacement(
                frame: frame,
                direction: resolvedDirection(
                    requested: direction,
                    frame: frame,
                    anchor: anchor
                ),
                screenIdentifier: screen.identifier,
                anchorFrame: anchor
            )
        }
        return placements.first { placement in
            avoidedFrames.allSatisfy { !placement.frame.intersects($0) }
        } ?? placements.min { lhs, rhs in
            overlapArea(of: lhs.frame, with: avoidedFrames)
                < overlapArea(of: rhs.frame, with: avoidedFrames)
        } ?? InputPanelPlacement(
            frame: NSRect(origin: .zero, size: panelSize),
            direction: .below,
            screenIdentifier: screen.identifier,
            anchorFrame: anchor
        )
    }

    static func screenGeometry(_ screen: NSScreen) -> InputPanelScreenGeometry {
        let numberKey = NSDeviceDescriptionKey("NSScreenNumber")
        let identifier = (screen.deviceDescription[numberKey] as? NSNumber)
            .map(String.init(describing:)) ?? String(describing: screen.frame)
        return InputPanelScreenGeometry(
            identifier: identifier,
            frame: screen.frame,
            visibleFrame: screen.visibleFrame
        )
    }

    /// Without the input position, a point at the mouse
    static func resolvedAnchor(
        _ anchor: NSRect,
        fallbackPoint: NSPoint
    ) -> NSRect {
        anchor == .zero
            ? NSRect(origin: fallbackPoint, size: NSSize(width: 1, height: 1))
            : anchor
    }

    private static func targetScreen(
        for anchor: NSRect,
        screens: [InputPanelScreenGeometry]
    ) -> InputPanelScreenGeometry? {
        let intersecting = screens.max { lhs, rhs in
            intersectionArea(lhs.frame, anchor) < intersectionArea(rhs.frame, anchor)
        }
        if let intersecting,
           intersectionArea(intersecting.frame, anchor) > 0 {
            return intersecting
        }
        let point = NSPoint(x: anchor.midX, y: anchor.midY)
        return screens.min { lhs, rhs in
            squaredDistance(from: point, to: lhs.frame)
                < squaredDistance(from: point, to: rhs.frame)
        }
    }

    private static func clampedOrigin(
        _ origin: NSPoint,
        panelSize: NSSize,
        visibleFrame: NSRect
    ) -> NSPoint {
        NSPoint(
            x: min(
                max(origin.x, visibleFrame.minX),
                max(visibleFrame.maxX - panelSize.width, visibleFrame.minX)
            ),
            y: min(
                max(origin.y, visibleFrame.minY),
                max(visibleFrame.maxY - panelSize.height, visibleFrame.minY)
            )
        )
    }

    private static func resolvedDirection(
        requested: InputPanelVerticalPlacement,
        frame: NSRect,
        anchor: NSRect
    ) -> InputPanelVerticalPlacement {
        if frame.maxY <= anchor.minY { return .below }
        if frame.minY >= anchor.maxY { return .above }
        return requested
    }

    private static func overlapArea(
        of frame: NSRect,
        with avoidedFrames: [NSRect]
    ) -> CGFloat {
        avoidedFrames.reduce(0) { result, avoided in
            result + intersectionArea(frame, avoided)
        }
    }

    private static func intersectionArea(_ lhs: NSRect, _ rhs: NSRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }

    private static func squaredDistance(from point: NSPoint, to rect: NSRect) -> CGFloat {
        let x = min(max(point.x, rect.minX), rect.maxX)
        let y = min(max(point.y, rect.minY), rect.maxY)
        return pow(point.x - x, 2) + pow(point.y - y, 2)
    }
}
