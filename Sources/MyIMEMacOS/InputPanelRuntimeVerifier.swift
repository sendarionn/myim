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
        let keepsPanelsVisible = previewSeconds > 0
        if keepsPanelsVisible {
            _ = NSApp.setActivationPolicy(.accessory)
            NSApp.activate(ignoringOtherApps: true)
        }
        let calendar = CalendarWindowController()
        let emoji = EmojiWindowController()
        let calendarMeasurements = calendar.runtimePanelMeasurements(
            keepsPanelVisible: keepsPanelsVisible
        )
        let emojiMeasurements = emoji.runtimePanelMeasurements(
            keepsPanelVisible: keepsPanelsVisible
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
        print("PANEL_RUNTIME_RESULT=passed")
        if previewSeconds > 0 {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: previewSeconds))
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

    private static func verificationError(_ message: String) -> NSError {
        NSError(
            domain: "myim.panel-runtime-verification",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
