// The window Scripts/update-readme.sh records myim in: a borderless window
// with one plain text view, so only the typed text and myim's panels show.
// Each launch starts empty; the text is written to the file given by
// --text-file whenever it changes, so the script can check the result.
// Keys the GUI helper presses are shown for a moment at the bottom.
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

/// A key cap drawn over the text, which never takes clicks or keys
final class KeyCapView: NSView {
    var label = "" { didSet { needsDisplay = true } }
    private let font = NSFont.systemFont(ofSize: 20, weight: .semibold)

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    var preferredSize: NSSize {
        let size = (label as NSString).size(withAttributes: [.font: font])
        return NSSize(width: ceil(size.width) + 32, height: ceil(size.height) + 16)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.labelColor.withAlphaComponent(0.14).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
        let size = (label as NSString).size(withAttributes: attributes)
        (label as NSString).draw(
            at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2),
            withAttributes: attributes
        )
    }
}

final class StageDelegate: NSObject, NSApplicationDelegate, NSTextViewDelegate {
    private var window: StageWindow?
    private var textFile: URL?
    private let keyCap = KeyCapView()
    private var keyCapTimer: Timer?

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
        // Room above the text for panels myim opens over it
        textView.textContainerInset = NSSize(width: 56, height: 76)
        textView.isRichText = false
        textView.allowsUndo = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.delegate = self
        window.contentView = textView
        keyCap.isHidden = true
        textView.addSubview(keyCap)
        self.window = window
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(showKey(_:)),
            name: Notification.Name("io.github.sendarionn.myim.readme-stage.key"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(textView)
    }

    /// Bottom center, below where myim's panels open near the text
    @objc private func showKey(_ notification: Notification) {
        guard let label = notification.object as? String,
              let bounds = window?.contentView?.bounds else { return }
        keyCap.label = label
        let size = keyCap.preferredSize
        // The text view is flipped, so the bottom is at its height
        keyCap.frame = NSRect(
            x: bounds.midX - size.width / 2,
            y: bounds.height - size.height - 28,
            width: size.width,
            height: size.height
        )
        keyCap.isHidden = false
        keyCapTimer?.invalidate()
        keyCapTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) {
            [weak self] _ in self?.keyCap.isHidden = true
        }
        RunLoop.main.add(keyCapTimer!, forMode: .common)
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
