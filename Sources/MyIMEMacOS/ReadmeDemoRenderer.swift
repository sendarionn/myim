@preconcurrency import AppKit
import ImageIO
import MyIMECore
import UniformTypeIdentifiers

/// Development command for README demos: draws each step of a conversion
/// with an AppKit text view and the real candidate panel, without an input
/// method session, screen recording or accessibility permission
@MainActor
enum ReadmeDemoRenderer {
    private struct Step {
        enum Text {
            case marked(String)
            case committed(String)
        }

        let text: Text
        let candidateInput: String?
        let selectedIndex: Int?
        let delay: Double
    }

    private static let windowSize = NSSize(width: 520, height: 260)
    private static let textInset = NSSize(width: 28, height: 30)
    private static let fontSize: CGFloat = 22

    static func render(scenario: String, to output: URL) throws {
        let steps: [Step]
        switch scenario {
        case "basic-conversion":
            steps = try basicConversion()
        default:
            throw error("未対応のデモシナリオです: \(scenario)")
        }
        let application = NSApplication.shared
        application.setActivationPolicy(.prohibited)
        application.appearance = NSAppearance(named: .aqua)
        let frames = try steps.map { step in
            (image: try frame(for: step), delay: step.delay)
        }
        try writeGIF(frames, to: output)
    }

    /// k → ko → kou → kouh → kouho with the candidates myim shows while
    /// typing, Tab selects the first candidate and Return commits it
    private static func basicConversion() throws -> [Step] {
        let input = "kouho"
        guard let selected = InputController.bundledCandidatePage(for: input)
            .first else {
            throw error("候補がありません: \(input)")
        }
        var steps = [Step(
            text: .marked(""),
            candidateInput: nil,
            selectedIndex: nil,
            delay: 0.8
        )]
        for length in 1...input.count {
            let typed = String(input.prefix(length))
            steps.append(Step(
                text: .marked(typed),
                candidateInput: typed,
                selectedIndex: nil,
                delay: length == input.count ? 1.0 : 0.3
            ))
        }
        steps.append(Step(
            text: .marked(selected.commitText),
            candidateInput: input,
            selectedIndex: 0,
            delay: 1.2
        ))
        steps.append(Step(
            text: .committed(selected.commitText),
            candidateInput: nil,
            selectedIndex: nil,
            delay: 2.0
        ))
        return steps
    }

    private static func frame(for step: Step) throws -> NSBitmapImageRep {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
        // The panel's shadow is drawn by the window server and is not in
        // the image, so the demo field differs from the panel background
        window.backgroundColor = .underPageBackgroundColor
        let textView = NSTextView(
            frame: NSRect(origin: .zero, size: windowSize)
        )
        textView.font = .systemFont(ofSize: fontSize)
        textView.textContainerInset = textInset
        textView.drawsBackground = true
        textView.backgroundColor = .underPageBackgroundColor
        window.contentView = textView
        switch step.text {
        case let .marked(value):
            // Clients receive myim's text through InputMethodKit, which
            // underlines it instead of the text view's own highlight
            textView.markedTextAttributes = [:]
            textView.setMarkedText(
                NSAttributedString(string: value, attributes: [
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .font: NSFont.systemFont(ofSize: fontSize)
                ]),
                selectedRange: NSRange(location: value.utf16.count, length: 0),
                replacementRange: NSRange(location: NSNotFound, length: 0)
            )
        case let .committed(value):
            textView.string = value
        }
        textView.layoutSubtreeIfNeeded()
        guard let canvas = image(of: window.contentView?.superview
            ?? textView) else {
            throw error("入力欄を描画できません")
        }
        guard let candidateInput = step.candidateInput else { return canvas }
        let page = InputController.bundledCandidatePage(for: candidateInput)
        guard !page.isEmpty else { return canvas }

        let markedRange = textView.hasMarkedText()
            ? textView.markedRange()
            : NSRange(location: 0, length: 0)
        let anchor = textView.firstRect(
            forCharacterRange: NSRange(location: markedRange.location, length: 0),
            actualRange: nil
        )
        let panel = CandidateWindowController()
        panel.layout(
            candidates: page.map(\.displayText),
            alternateCommitIndicators: page.map(\.hasDistinctCommitText),
            selectedIndex: step.selectedIndex,
            near: anchor
        )
        guard let panelImage = panel.renderedImage() else {
            throw error("候補パネルを描画できません")
        }
        draw(
            panelImage,
            at: NSPoint(
                x: panel.frame.minX - window.frame.minX,
                y: panel.frame.minY - window.frame.minY
            ),
            onto: canvas
        )
        return canvas
    }

    private static func image(of view: NSView) -> NSBitmapImageRep? {
        view.layoutSubtreeIfNeeded()
        guard let image = view.bitmapImageRepForCachingDisplay(
            in: view.bounds
        ) else { return nil }
        view.cacheDisplay(in: view.bounds, to: image)
        return image
    }

    private static func draw(
        _ overlay: NSBitmapImageRep,
        at origin: NSPoint,
        onto canvas: NSBitmapImageRep
    ) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: canvas)
        overlay.draw(in: NSRect(origin: origin, size: overlay.size))
    }

    /// Written next to `output` first, so a failure leaves the previous GIF
    private static func writeGIF(
        _ frames: [(image: NSBitmapImageRep, delay: Double)],
        to output: URL
    ) throws {
        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let temporary = output.deletingLastPathComponent()
            .appendingPathComponent(".\(output.lastPathComponent).tmp")
        try? FileManager.default.removeItem(at: temporary)
        defer { try? FileManager.default.removeItem(at: temporary) }
        guard let destination = CGImageDestinationCreateWithURL(
            temporary as CFURL,
            UTType.gif.identifier as CFString,
            frames.count,
            nil
        ) else {
            throw error("GIFを作成できません")
        }
        CGImageDestinationSetProperties(destination, [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
        ] as CFDictionary)
        for frame in frames {
            guard let image = frame.image.cgImage else {
                throw error("フレームを変換できません")
            }
            CGImageDestinationAddImage(destination, image, [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: frame.delay,
                    kCGImagePropertyGIFUnclampedDelayTime: frame.delay
                ]
            ] as CFDictionary)
        }
        guard CGImageDestinationFinalize(destination) else {
            throw error("GIFを書き出せません")
        }
        _ = try FileManager.default.replaceItemAt(output, withItemAt: temporary)
    }

    private static func error(_ message: String) -> NSError {
        NSError(
            domain: "myim.command",
            code: 6,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
