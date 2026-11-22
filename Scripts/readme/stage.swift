// The window Scripts/update-readme.sh records myim in: a borderless window
// with one plain text view, so only the typed text and myim's panels show.
// Each launch starts empty; the text is written to the file given by
// --text-file whenever it changes, so the script can check the result.
//
//   myim-readme-stage --frame <x> <y> <width> <height> --text-file <path>
//
// The frame is in points from the top left of the main display, as
// screencapture -R takes it.

import AppKit

final class StageWindow: NSWindow {
    // A borderless window does not take keys unless it says it can
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class StageDelegate: NSObject, NSApplicationDelegate, NSTextViewDelegate {
    private var window: StageWindow?
    private var textFile: URL?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let arguments = CommandLine.arguments
        var frame = NSRect(x: 120, y: 140, width: 640, height: 420)
        if let index = arguments.firstIndex(of: "--frame"), index + 4 < arguments.count {
            let numbers = arguments[(index + 1)...(index + 4)].compactMap(Double.init)
            if numbers.count == 4 {
                frame = NSRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
            }
        }
        if let index = arguments.firstIndex(of: "--text-file"), index + 1 < arguments.count {
            textFile = URL(fileURLWithPath: arguments[index + 1])
            try? "".write(to: textFile!, atomically: true, encoding: .utf8)
        }
        // From the top left of the main display to AppKit's bottom left
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        let contentRect = NSRect(
            x: frame.minX,
            y: screenHeight - frame.minY - frame.height,
            width: frame.width,
            height: frame.height
        )

        let window = StageWindow(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.hasShadow = false
        window.isOpaque = true
        window.backgroundColor = .textBackgroundColor
        window.animationBehavior = .none
        window.isReleasedWhenClosed = false

        let textView = NSTextView(frame: NSRect(origin: .zero, size: contentRect.size))
        textView.autoresizingMask = [.width, .height]
        textView.font = .systemFont(ofSize: 22)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.drawsBackground = true
        textView.textContainerInset = NSSize(width: 56, height: 48)
        textView.isRichText = false
        textView.allowsUndo = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.delegate = self
        window.contentView = textView
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(textView)
    }

    func textDidChange(_ notification: Notification) {
        guard let textFile,
              let textView = notification.object as? NSTextView else { return }
        try? textView.string.write(to: textFile, atomically: true, encoding: .utf8)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

let application = NSApplication.shared
let delegate = StageDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
