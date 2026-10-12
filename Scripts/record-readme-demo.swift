import AppKit
import Carbon
import Foundation
import ImageIO
import UniformTypeIdentifiers

private enum DemoRecordingError: LocalizedError {
    case invalidArguments
    case unsupportedScenario(String)
    case inputSourceNotFound
    case couldNotActivate(String)
    case operationFailed(String, OSStatus)
    case screenCaptureFailed
    case unexpectedResult(expected: String, actual: String)
    case gifCreationFailed

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            "使い方: record-readme-demo.swift <scenario> <output.gif> <expected-text>"
        case let .unsupportedScenario(value):
            "未対応のデモシナリオです: \(value)"
        case .inputSourceNotFound:
            "myimの入力ソースが見つかりません"
        case let .couldNotActivate(frontmost):
            "録画ウィンドウを前面化できませんでした。現在の前面アプリ=\(frontmost)"
        case let .operationFailed(operation, status):
            "\(operation)に失敗しました: \(status)"
        case .screenCaptureFailed:
            "画面収録に失敗しました。システム設定でmyim README demo recorderの画面収録を許可してください"
        case let .unexpectedResult(expected, actual):
            "デモ結果が不正です。期待値=\(expected) 実際=\(actual)"
        case .gifCreationFailed:
            "GIFの生成に失敗しました"
        }
    }
}

private struct InputSourceSelection {
    static let myIMIdentifier = "io.github.sendarionn.inputmethod.myime.Japanese"

    let previous: TISInputSource

    static func selectMyIM() throws -> InputSourceSelection {
        let previous = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let sources = TISCreateInputSourceList(nil, true).takeRetainedValue()
            as! [TISInputSource]
        guard let source = sources.first(where: {
            identifier(of: $0) == myIMIdentifier
        }) else {
            throw DemoRecordingError.inputSourceNotFound
        }
        let status = TISSelectInputSource(source)
        guard status == noErr else {
            throw DemoRecordingError.operationFailed("入力ソースの選択", status)
        }
        return InputSourceSelection(previous: previous)
    }

    func restore() {
        TISSelectInputSource(previous)
    }

    private static func identifier(of source: TISInputSource) -> String? {
        guard let pointer = TISGetInputSourceProperty(
            source,
            kTISPropertyInputSourceID
        ) else { return nil }
        return Unmanaged<CFString>
            .fromOpaque(pointer)
            .takeUnretainedValue() as String
    }
}

private final class DemoInputWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class DemoApplication {
    let window: NSWindow
    let textView: NSTextView

    init() {
        let screen = NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1_200, height: 800)
        let size = NSSize(width: 760, height: 420)
        let frame = NSRect(
            x: screen.midX - size.width / 2,
            y: screen.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        window = DemoInputWindow(
            contentRect: frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "myim demo"
        window.isReleasedWhenClosed = false

        let scrollView = NSScrollView(frame: window.contentView!.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = true

        textView = NSTextView(frame: scrollView.contentView.bounds)
        textView.autoresizingMask = [.width, .height]
        textView.font = NSFont.systemFont(ofSize: 30)
        textView.textContainerInset = NSSize(width: 36, height: 44)
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.string = ""
        scrollView.documentView = textView
        window.contentView?.addSubview(scrollView)
    }

    func show() {
        NSApp.setActivationPolicy(.regular)
        window.orderFrontRegardless()
        window.makeMain()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(textView)
    }

    func activateAndWait() throws {
        let current = NSRunningApplication.current
        current.activate(options: [.activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        window.makeMain()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(textView)
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier
                == ProcessInfo.processInfo.processIdentifier,
               window.isKeyWindow {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        let frontmost = NSWorkspace.shared.frontmostApplication?
            .localizedName ?? "不明"
        throw DemoRecordingError.couldNotActivate(frontmost)
    }

    func sendKey(
        keyCode: UInt16,
        characters: String,
        modifiers: NSEvent.ModifierFlags = []
    ) throws {
        try activateAndWait()
        guard let down = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters.lowercased(),
            isARepeat: false,
            keyCode: keyCode
        ), let up = NSEvent.keyEvent(
            with: .keyUp,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters.lowercased(),
            isARepeat: false,
            keyCode: keyCode
        ) else {
            throw DemoRecordingError.operationFailed("キーイベントの生成", -1)
        }
        let handledByInputMethod = textView.inputContext?.handleEvent(down)
            ?? false
        if !handledByInputMethod {
            NSApp.sendEvent(down)
        }
        NSApp.sendEvent(up)
    }
}

private final class DemoRecorder {
    private let application: DemoApplication
    private let directory: URL
    private var frameURLs: [URL] = []
    private let frameDelay = 0.12

    init(application: DemoApplication) throws {
        self.application = application
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("myim-readme-demo-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    func waitAndCapture(count: Int, interval: TimeInterval = 0.14) throws {
        for _ in 0..<count {
            RunLoop.current.run(until: Date().addingTimeInterval(interval))
            try captureFrame()
        }
    }

    func writeGIF(to output: URL) throws {
        guard !frameURLs.isEmpty else {
            throw DemoRecordingError.gifCreationFailed
        }
        let temporary = output.deletingLastPathComponent()
            .appendingPathComponent(".\(output.lastPathComponent).tmp")
        try? FileManager.default.removeItem(at: temporary)
        guard let destination = CGImageDestinationCreateWithURL(
            temporary as CFURL,
            UTType.gif.identifier as CFString,
            frameURLs.count,
            nil
        ) else {
            throw DemoRecordingError.gifCreationFailed
        }
        CGImageDestinationSetProperties(destination, [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: 0
            ]
        ] as CFDictionary)
        for frameURL in frameURLs {
            guard let source = CGImageSourceCreateWithURL(
                frameURL as CFURL,
                nil
            ), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw DemoRecordingError.gifCreationFailed
            }
            CGImageDestinationAddImage(destination, image, [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: frameDelay,
                    kCGImagePropertyGIFUnclampedDelayTime: frameDelay
                ]
            ] as CFDictionary)
        }
        guard CGImageDestinationFinalize(destination) else {
            throw DemoRecordingError.gifCreationFailed
        }
        try? FileManager.default.removeItem(at: output)
        try FileManager.default.moveItem(at: temporary, to: output)
    }

    private func captureFrame() throws {
        guard let screen = application.window.screen ?? NSScreen.main else {
            throw DemoRecordingError.screenCaptureFailed
        }
        let frame = application.window.frame
        let x = Int(frame.minX.rounded(.down))
        let y = Int((screen.frame.maxY - frame.maxY).rounded(.down))
        let width = Int(frame.width.rounded(.up))
        let height = Int(frame.height.rounded(.up))
        let url = directory.appendingPathComponent(
            String(format: "frame-%04d.png", frameURLs.count)
        )
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = [
            "-x",
            "-R\(x),\(y),\(width),\(height)",
            url.path
        ]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              FileManager.default.fileExists(atPath: url.path) else {
            throw DemoRecordingError.screenCaptureFailed
        }
        frameURLs.append(url)
    }
}

private func runInputDemo(
    output: URL,
    expectedText: String,
    input: [(UInt16, String, NSEvent.ModifierFlags)]
) throws {
    let application = DemoApplication()
    application.show()
    try application.activateAndWait()
    let sourceSelection = try InputSourceSelection.selectMyIM()
    defer { sourceSelection.restore() }
    try application.activateAndWait()
    RunLoop.current.run(until: Date().addingTimeInterval(0.3))
    let recorder = try DemoRecorder(application: application)
    try recorder.waitAndCapture(count: 3)
    try application.activateAndWait()

    for (keyCode, characters, modifiers) in input {
        try application.sendKey(
            keyCode: keyCode,
            characters: characters,
            modifiers: modifiers
        )
        try recorder.waitAndCapture(count: 2)
    }
    try recorder.waitAndCapture(count: 4)
    try application.sendKey(keyCode: 48, characters: "\t")
    try recorder.waitAndCapture(count: 4)
    try application.sendKey(keyCode: 36, characters: "\r")
    try recorder.waitAndCapture(count: 4)

    let actual = application.textView.string
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard actual == expectedText else {
        throw DemoRecordingError.unexpectedResult(
            expected: expectedText,
            actual: actual
        )
    }
    try recorder.writeGIF(to: output)
    application.window.close()
}

guard CommandLine.arguments.count == 4 else {
    throw DemoRecordingError.invalidArguments
}

let scenario = CommandLine.arguments[1]
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let expectedText = CommandLine.arguments[3]
let errorReport = URL(fileURLWithPath: output.path + ".error.txt")
try? FileManager.default.removeItem(at: errorReport)
try FileManager.default.createDirectory(
    at: output.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

let application = NSApplication.shared
var result: Result<Void, Error>?
DispatchQueue.main.async {
    do {
        switch scenario {
        case "calculation":
            try runInputDemo(
                output: output,
                expectedText: expectedText,
                input: [
                    (18, "1", []),
                    (24, "+", [.shift]),
                    (19, "2", []),
                    (24, "=", [])
                ]
            )
        case "basic-conversion":
            try runInputDemo(
                output: output,
                expectedText: expectedText,
                input: [
                    (40, "k", []),
                    (31, "o", []),
                    (32, "u", []),
                    (4, "h", []),
                    (31, "o", [])
                ]
            )
        default:
            throw DemoRecordingError.unsupportedScenario(scenario)
        }
        result = .success(())
    } catch {
        result = .failure(error)
    }
    application.stop(nil)
    if let wakeEvent = NSEvent.otherEvent(
        with: .applicationDefined,
        location: .zero,
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: 0,
        context: nil,
        subtype: 0,
        data1: 0,
        data2: 0
    ) {
        application.postEvent(wakeEvent, atStart: false)
    }
}
application.run()

switch result {
case .success:
    try? FileManager.default.removeItem(at: errorReport)
    print("生成しました: \(output.path)")
case let .failure(error):
    try? error.localizedDescription.write(
        to: errorReport,
        atomically: true,
        encoding: .utf8
    )
    fputs("エラー: \(error.localizedDescription)\n", stderr)
    exit(1)
case nil:
    fputs("エラー: デモ録画が完了しませんでした\n", stderr)
    exit(1)
}
