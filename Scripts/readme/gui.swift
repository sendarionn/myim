// Small GUI helper for Scripts/update-readme.sh: posts keys and drags to a
// test editor, finds myim's accessibility elements, and switches the input
// source. Every input command first checks the frontmost application and
// stops without sending anything when it is not one that was expected, so
// keys never reach an application the user is working in.
//
//   gui check
//   gui frontmost
//   gui input-source
//   gui select-input-source <id>
//   gui key <keycode> [option|shift|command|control ...] --expect <ids>
//   gui element-frame <process name> <label prefix>
//   gui drag <x1> <y1> <x2> <y2> --expect <ids>
//
// Coordinates are global and top-left based, as Quartz and screencapture
// use them. `<ids>` is a comma-separated list of bundle identifiers.

import AppKit
import ApplicationServices
import Carbon
import CoreGraphics
import Foundation

func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

func frontmostIdentifier() -> String {
    NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
}

/// Exit 4 unless the frontmost application is one of `expected`
func requireFrontmost(_ arguments: [String]) {
    guard let index = arguments.firstIndex(of: "--expect"),
          index + 1 < arguments.count else {
        fail("--expect is required for input commands")
    }
    let expected = arguments[index + 1].split(separator: ",").map(String.init)
    let current = frontmostIdentifier()
    guard expected.contains(current) else {
        fail("frontmost is \(current), expected \(expected.joined(separator: ","))",
             code: 4)
    }
}

func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags) {
    let source = CGEventSource(stateID: .hidSystemState)
    for isDown in [true, false] {
        let event = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCode,
            keyDown: isDown
        )
        event?.flags = flags
        event?.post(tap: .cghidEventTap)
        usleep(30_000)
    }
}

func postMouse(_ type: CGEventType, at point: CGPoint) {
    CGEvent(
        mouseEventSource: CGEventSource(stateID: .hidSystemState),
        mouseType: type,
        mouseCursorPosition: point,
        mouseButton: .left
    )?.post(tap: .cghidEventTap)
}

func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
    var value: AnyObject?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value)
        == .success else { return nil }
    return value
}

func frame(of element: AXUIElement) -> CGRect? {
    guard let positionValue = attribute(element, kAXPositionAttribute),
          let sizeValue = attribute(element, kAXSizeAttribute) else {
        return nil
    }
    var position = CGPoint.zero
    var size = CGSize.zero
    AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
    AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
    return CGRect(origin: position, size: size)
}

/// Depth-first search for the first element whose description or title
/// starts with `prefix`
func findElement(in element: AXUIElement, prefix: String, depth: Int = 0)
    -> AXUIElement? {
    for name in [kAXDescriptionAttribute, kAXTitleAttribute] {
        if let text = attribute(element, name) as? String,
           text.hasPrefix(prefix) {
            return element
        }
    }
    guard depth < 12 else { return nil }
    var children: [AXUIElement] = []
    for name in [kAXChildrenAttribute, kAXWindowsAttribute] {
        if let values = attribute(element, name) as? [AXUIElement] {
            children += values
        }
    }
    for child in children {
        if let found = findElement(in: child, prefix: prefix, depth: depth + 1) {
            return found
        }
    }
    return nil
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else { fail("no command") }

switch command {
case "check":
    var missing: [String] = []
    if !AXIsProcessTrusted() { missing.append("アクセシビリティ") }
    if !CGPreflightScreenCaptureAccess() { missing.append("画面収録") }
    guard missing.isEmpty else {
        fail("この端末アプリに次の権限がありません: \(missing.joined(separator: "、"))\n"
            + "システム設定 > プライバシーとセキュリティで許可してください", code: 3)
    }
    print("ok")

case "frontmost":
    print(frontmostIdentifier())

case "input-source":
    let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    let id = TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
    print(id.map { Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String } ?? "")

case "select-input-source":
    guard arguments.count == 2 else { fail("usage: select-input-source <id>") }
    let filter = [kTISPropertyInputSourceID as String: arguments[1]] as CFDictionary
    guard let sources = TISCreateInputSourceList(filter, false)?
        .takeRetainedValue() as? [TISInputSource],
          let source = sources.first,
          TISSelectInputSource(source) == noErr else {
        fail("input source not found: \(arguments[1])")
    }
    print("ok")

case "key":
    requireFrontmost(arguments)
    guard arguments.count >= 2, let code = UInt16(arguments[1]) else {
        fail("usage: key <keycode> [modifiers] --expect <ids>")
    }
    var flags: CGEventFlags = []
    for name in arguments.dropFirst(2) {
        switch name {
        case "option": flags.insert(.maskAlternate)
        case "shift": flags.insert(.maskShift)
        case "command": flags.insert(.maskCommand)
        case "control": flags.insert(.maskControl)
        default: break
        }
    }
    postKey(code, flags: flags)

case "element-frame":
    guard arguments.count == 3 else {
        fail("usage: element-frame <process name> <label prefix>")
    }
    guard let application = NSWorkspace.shared.runningApplications.first(where: {
        $0.executableURL?.lastPathComponent == arguments[1]
    }) else { fail("process not running: \(arguments[1])") }
    let root = AXUIElementCreateApplication(application.processIdentifier)
    guard let element = findElement(in: root, prefix: arguments[2]),
          let rect = frame(of: element) else {
        fail("element not found: \(arguments[2])", code: 5)
    }
    print("\(Int(rect.minX)) \(Int(rect.minY)) \(Int(rect.width)) \(Int(rect.height))")

case "drag":
    requireFrontmost(arguments)
    let numbers = arguments.dropFirst().prefix(4).compactMap(Double.init)
    guard numbers.count == 4 else {
        fail("usage: drag <x1> <y1> <x2> <y2> --expect <ids>")
    }
    let start = CGPoint(x: numbers[0], y: numbers[1])
    let end = CGPoint(x: numbers[2], y: numbers[3])
    postMouse(.mouseMoved, at: start)
    usleep(150_000)
    postMouse(.leftMouseDown, at: start)
    usleep(150_000)
    // Moved steadily, never held still long enough to zoom the rail
    let steps = 24
    for step in 1...steps {
        let fraction = Double(step) / Double(steps)
        postMouse(.leftMouseDragged, at: CGPoint(
            x: start.x + (end.x - start.x) * fraction,
            y: start.y + (end.y - start.y) * fraction
        ))
        usleep(25_000)
    }
    usleep(100_000)
    postMouse(.leftMouseUp, at: end)

default:
    fail("unknown command: \(command)")
}
