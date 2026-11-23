@preconcurrency import AppKit

enum InputPanelRuntimeVerifier {
    private static let expectedSize = NSSize(width: 240, height: 240)
    private static let tolerance: CGFloat = 0.5

    static func verify() throws {
        _ = NSApplication.shared
        NSApp.finishLaunching()
        let previewSeconds = ProcessInfo.processInfo.environment[
            "MYIM_PANEL_RUNTIME_PREVIEW_SECONDS"
        ].flatMap(TimeInterval.init) ?? 0
        let previewPanel = ProcessInfo.processInfo.environment[
            "MYIM_PANEL_RUNTIME_PREVIEW_PANEL"
        ]
        if previewSeconds > 0 {
            _ = NSApp.setActivationPolicy(.accessory)
            NSApp.activate(ignoringOtherApps: true)
        }
        let placementCases = runtimePlacementCases()
        let calendar = CalendarWindowController()
        let emoji = EmojiWindowController()
        let calendarMeasurements = calendar.runtimePanelMeasurements(
            keepsPanelVisible: previewPanel == "calendar",
            placementCases: placementCases
        )
        let emojiMeasurements = emoji.runtimePanelMeasurements(
            keepsPanelVisible: previewPanel == "emoji",
            placementCases: placementCases
        )
        let allMeasurements = calendarMeasurements + emojiMeasurements

        for measurement in allMeasurements {
            print(measurement.report)
            try requireSize(measurement.frameSize, label: "\(measurement.label) frame")
            try requireSize(
                measurement.contentRectSize,
                label: "\(measurement.label) contentRect"
            )
            try requireSize(
                measurement.contentViewSize,
                label: "\(measurement.label) contentView"
            )
            if !measurement.label.hasSuffix("-created"), !measurement.isVisible {
                throw verificationError("\(measurement.label) is not visible")
            }
        }

        guard let calendarStyle = calendarMeasurements.first,
              let emojiStyle = emojiMeasurements.first else {
            throw verificationError("パネル計測結果がありません")
        }
        try requireEqual(
            calendarStyle.frameSize,
            emojiStyle.frameSize,
            label: "calendar and emoji frame"
        )
        guard calendarStyle.level == emojiStyle.level,
              calendarStyle.hasShadow == emojiStyle.hasShadow,
              calendarStyle.isOpaque == emojiStyle.isOpaque,
              calendarStyle.backgroundColor == emojiStyle.backgroundColor else {
            throw verificationError("カレンダーと絵文字の共通スタイルが一致しません")
        }
        try verifyPlacements(
            calendarMeasurements: calendarMeasurements,
            emojiMeasurements: emojiMeasurements,
            cases: placementCases
        )
        print("PHYSICAL_DISPLAY_COUNT=\(NSScreen.screens.count)")
        print(NSScreen.screens.count > 1
            ? "PHYSICAL_MULTI_DISPLAY=available"
            : "PHYSICAL_MULTI_DISPLAY=unverified")
        print("SIMULATED_MULTI_DISPLAY=passed")
        print("PANEL_RUNTIME_RESULT=passed")
        if previewSeconds > 0 {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: previewSeconds))
        }
    }

    private static func runtimePlacementCases() -> [InputPanelPlacementCase] {
        let physicalScreens = NSScreen.screens.map(InputPanelPositioning.screenGeometry)
        let primary = physicalScreens.first ?? InputPanelScreenGeometry(
            identifier: "runtime-primary",
            frame: NSRect(x: 0, y: 0, width: 1200, height: 900),
            visibleFrame: NSRect(x: 0, y: 0, width: 1200, height: 900)
        )
        let visible = primary.visibleFrame
        let center = NSRect(
            x: visible.midX - 30,
            y: visible.midY,
            width: 1,
            height: 20
        )
        let simulatedScreens = [
            InputPanelScreenGeometry(
                identifier: "simulated-left",
                frame: NSRect(x: 0, y: 0, width: 1000, height: 800),
                visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800)
            ),
            InputPanelScreenGeometry(
                identifier: "simulated-right",
                frame: NSRect(x: 1000, y: 0, width: 1000, height: 800),
                visibleFrame: NSRect(x: 1000, y: 0, width: 1000, height: 800)
            )
        ]
        let commonFallback = NSPoint(x: visible.midX, y: visible.midY)
        return [
            InputPanelPlacementCase(
                label: "center",
                anchorFrame: center,
                screens: physicalScreens,
                avoidedFrames: [],
                fallbackPoint: commonFallback
            ),
            InputPanelPlacementCase(
                label: "left-edge",
                anchorFrame: NSRect(
                    x: visible.minX + 1,
                    y: visible.midY,
                    width: 1,
                    height: 20
                ),
                screens: physicalScreens,
                avoidedFrames: [],
                fallbackPoint: commonFallback
            ),
            InputPanelPlacementCase(
                label: "right-edge",
                anchorFrame: NSRect(
                    x: visible.maxX - 1,
                    y: visible.midY,
                    width: 1,
                    height: 20
                ),
                screens: physicalScreens,
                avoidedFrames: [],
                fallbackPoint: commonFallback
            ),
            InputPanelPlacementCase(
                label: "top-edge",
                anchorFrame: NSRect(
                    x: visible.midX,
                    y: visible.maxY - 21,
                    width: 1,
                    height: 20
                ),
                screens: physicalScreens,
                avoidedFrames: [],
                fallbackPoint: commonFallback
            ),
            InputPanelPlacementCase(
                label: "bottom-edge",
                anchorFrame: NSRect(
                    x: visible.midX,
                    y: visible.minY + 1,
                    width: 1,
                    height: 20
                ),
                screens: physicalScreens,
                avoidedFrames: [],
                fallbackPoint: commonFallback
            ),
            InputPanelPlacementCase(
                label: "overlap-avoidance",
                anchorFrame: center,
                screens: physicalScreens,
                avoidedFrames: [NSRect(
                    x: center.minX,
                    y: center.minY - InputPanelPositioning.panelSize.height
                        - InputPanelPositioning.anchorSpacing,
                    width: InputPanelPositioning.panelSize.width,
                    height: InputPanelPositioning.panelSize.height
                )],
                fallbackPoint: commonFallback
            ),
            InputPanelPlacementCase(
                label: "fallback",
                anchorFrame: .zero,
                screens: physicalScreens,
                avoidedFrames: [],
                fallbackPoint: commonFallback
            ),
            InputPanelPlacementCase(
                label: "multiple-displays",
                anchorFrame: NSRect(x: 1200, y: 400, width: 1, height: 20),
                screens: simulatedScreens,
                avoidedFrames: [],
                fallbackPoint: .zero
            )
        ]
    }

    private static func verifyPlacements(
        calendarMeasurements: [InputPanelRuntimeSnapshot],
        emojiMeasurements: [InputPanelRuntimeSnapshot],
        cases: [InputPanelPlacementCase]
    ) throws {
        for placementCase in cases + [cases[0].relabeled("redisplayed")] {
            let calendarLabel = "calendar-placement-\(placementCase.label)"
            let emojiLabel = "emoji-placement-\(placementCase.label)"
            guard let calendar = calendarMeasurements.first(where: {
                $0.label == calendarLabel
            }), let emoji = emojiMeasurements.first(where: {
                $0.label == emojiLabel
            }), let calendarPlacement = calendar.placement,
                  let emojiPlacement = emoji.placement else {
                throw verificationError("\(placementCase.label) の配置計測結果がありません")
            }
            try requireEqual(
                calendar.frameOrigin,
                emoji.frameOrigin,
                label: "\(placementCase.label) origin"
            )
            try requireEqual(
                calendar.frameSize,
                emoji.frameSize,
                label: "\(placementCase.label) frame"
            )
            try requireSpecification(calendar, case: placementCase)
            guard calendarPlacement.direction == emojiPlacement.direction,
                  calendarPlacement.screenIdentifier
                    == emojiPlacement.screenIdentifier,
                  abs(calendarPlacement.anchorDistance
                    - emojiPlacement.anchorDistance) <= tolerance else {
                throw verificationError("\(placementCase.label) の配置情報が一致しません")
            }
        }
    }

    /// Inside the screen, clear of the other panels, and, where there is
    /// room, at the input position's left edge 8pt below it
    private static func requireSpecification(
        _ measurement: InputPanelRuntimeSnapshot,
        case placementCase: InputPanelPlacementCase
    ) throws {
        guard let placement = measurement.placement,
              let screen = placementCase.screens.first(where: {
                  $0.identifier == placement.screenIdentifier
              }) else {
            throw verificationError("\(placementCase.label) の表示先画面がありません")
        }
        let frame = NSRect(origin: measurement.frameOrigin, size: measurement.frameSize)
        guard screen.visibleFrame.insetBy(dx: -tolerance, dy: -tolerance)
            .contains(frame) else {
            throw verificationError("\(placementCase.label) が画面からはみ出しています")
        }
        guard placementCase.avoidedFrames.allSatisfy({
            !frame.insetBy(dx: tolerance, dy: tolerance).intersects($0)
        }) else {
            throw verificationError("\(placementCase.label) が他のパネルと重なっています")
        }
        let anchor = placement.anchorFrame
        let fitsBelow = anchor.minY - expectedSize.height
            - InputPanelPositioning.anchorSpacing >= screen.visibleFrame.minY
        let fitsRight = anchor.minX + expectedSize.width <= screen.visibleFrame.maxX
        if placementCase.avoidedFrames.isEmpty, fitsBelow, fitsRight,
           anchor.minX >= screen.visibleFrame.minX {
            guard placement.direction == .below,
                  abs(frame.minX - anchor.minX) <= tolerance,
                  abs(placement.anchorDistance - InputPanelPositioning.anchorSpacing)
                    <= tolerance else {
                throw verificationError("\(placementCase.label) が入力位置の左端8pt下にありません")
            }
        }
    }

    private static func requireSize(_ actual: NSSize, label: String) throws {
        try requireEqual(actual, expectedSize, label: label)
    }

    private static func requireEqual(
        _ lhs: NSSize,
        _ rhs: NSSize,
        label: String
    ) throws {
        guard abs(lhs.width - rhs.width) <= tolerance,
              abs(lhs.height - rhs.height) <= tolerance else {
            throw verificationError(
                "\(label) size mismatch: \(lhs.width)x\(lhs.height) != \(rhs.width)x\(rhs.height)"
            )
        }
    }

    private static func requireEqual(
        _ lhs: NSPoint,
        _ rhs: NSPoint,
        label: String
    ) throws {
        guard abs(lhs.x - rhs.x) <= tolerance,
              abs(lhs.y - rhs.y) <= tolerance else {
            throw verificationError(
                "\(label) mismatch: \(lhs.x),\(lhs.y) != \(rhs.x),\(rhs.y)"
            )
        }
    }

    private static func verificationError(_ message: String) -> NSError {
        NSError(
            domain: "myim.panel-runtime-verification",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
