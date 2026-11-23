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
//   gui type <ascii text> [--delay <milliseconds>] --expect <ids>
//   gui element-frame <process name> <label prefix>
//   gui ax-press <process name> <label prefix> [--menu-bar-extra]
//   gui ax-dump <process name> [depth]
//   gui drag <x1> <y1> <x2> <y2> --expect <ids>
//   gui click <x> <y> --expect <ids>
//   gui scroll <x> <y> <lines> --expect <ids>   negative lines scroll down
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

/// What the recording window shows for a key, such as `⌥ T` or `Tab`
func keyLabel(_ keyCode: UInt16, flags: CGEventFlags) -> String {
    var parts: [String] = []
    if flags.contains(.maskControl) { parts.append("⌃") }
    if flags.contains(.maskAlternate) { parts.append("⌥") }
    if flags.contains(.maskShift) { parts.append("⇧") }
    if flags.contains(.maskCommand) { parts.append("⌘") }
    let names: [UInt16: String] = [
        36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Esc",
        76: "Enter", 123: "←", 124: "→", 125: "↓", 126: "↑",
        97: "F6", 98: "F7", 100: "F8",
        17: "T", 8: "C", 11: "B", 12: "Q", 14: "E", 3: "F", 2: "D"
    ]
    parts.append(names[keyCode] ?? "Key \(keyCode)")
    return parts.joined(separator: " ")
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

/// US layout key codes for the characters scenarios type
let typedKeys: [Character: (code: CGKeyCode, shift: Bool)] = {
    var keys: [Character: (CGKeyCode, Bool)] = [:]
    let plain: [(Character, CGKeyCode)] = [
        ("a", 0), ("s", 1), ("d", 2), ("f", 3), ("h", 4), ("g", 5), ("z", 6),
        ("x", 7), ("c", 8), ("v", 9), ("b", 11), ("q", 12), ("w", 13),
        ("e", 14), ("r", 15), ("y", 16), ("t", 17), ("1", 18), ("2", 19),
        ("3", 20), ("4", 21), ("6", 22), ("5", 23), ("=", 24), ("9", 25),
        ("7", 26), ("-", 27), ("8", 28), ("0", 29), ("]", 30), ("o", 31),
        ("u", 32), ("[", 33), ("i", 34), ("p", 35), ("l", 37), ("j", 38),
        ("'", 39), ("k", 40), (";", 41), (",", 43), ("/", 44), ("n", 45),
        ("m", 46), (".", 47), ("`", 50), (" ", 49)
    ]
    for (character, code) in plain {
        keys[character] = (code, false)
        if character.isLetter {
            keys[Character(character.uppercased())] = (code, true)
        }
    }
    let shifted: [(Character, CGKeyCode)] = [
        ("*", 28), ("+", 24), ("(", 25), (")", 29), (":", 41), ("~", 50),
        ("?", 44), ("!", 18), ("_", 27)
    ]
    for (character, code) in shifted { keys[character] = (code, true) }
    return keys
}()

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

func dump(_ element: AXUIElement, depth: Int, limit: Int) {
    let role = attribute(element, kAXRoleAttribute) as? String ?? "?"
    let title = attribute(element, kAXTitleAttribute) as? String ?? ""
    let description = attribute(element, kAXDescriptionAttribute) as? String ?? ""
    print(String(repeating: "  ", count: depth) + "\(role) [\(title)] [\(description)]")
    guard depth < limit else { return }
    for name in [kAXChildrenAttribute, kAXWindowsAttribute, "AXExtrasMenuBar"] {
        for child in attribute(element, name) as? [AXUIElement] ?? [] {
            dump(child, depth: depth + 1, limit: limit)
        }
    }
}

/// Depth-first search for the first element whose description or title
/// starts with `prefix`
func findElement(in element: AXUIElement, prefix: String, depth: Int = 0)
    -> AXUIElement? {
    for name in [kAXDescriptionAttribute, kAXTitleAttribute, kAXValueAttribute] {
        if let text = attribute(element, name) as? String,
           text.hasPrefix(prefix) {
            return element
        }
    }
    guard depth < 12 else { return nil }
    var children: [AXUIElement] = []
    for name in [kAXChildrenAttribute, kAXWindowsAttribute, "AXExtrasMenuBar"] {
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
    // The recording window shows the key as it is pressed
    DistributedNotificationCenter.default().postNotificationName(
        Notification.Name("io.github.sendarionn.myim.readme-stage.key"),
        object: keyLabel(code, flags: flags),
        userInfo: nil,
        deliverImmediately: true
    )
    postKey(code, flags: flags)

case "type":
    requireFrontmost(arguments)
    guard arguments.count >= 2 else { fail("usage: type <text> --expect <ids>") }
    let text = arguments[1]
    guard text.allSatisfy({ typedKeys[$0] != nil }) else {
        fail("cannot type: \(text)")
    }
    var delay: UInt32 = 70
    if let index = arguments.firstIndex(of: "--delay"), index + 1 < arguments.count,
       let value = UInt32(arguments[index + 1]) {
        delay = value
    }
    for character in text {
        // Checked before every key, so typing stops if focus moves away
        requireFrontmost(arguments)
        let key = typedKeys[character]!
        postKey(key.code, flags: key.shift ? .maskShift : [])
        usleep(delay * 1000)
    }

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

case "ax-dump", "ax-press":
    guard arguments.count >= 2 else { fail("usage: \(command) <process name> ...") }
    guard let application = NSWorkspace.shared.runningApplications.first(where: {
        $0.executableURL?.lastPathComponent == arguments[1]
    }) else { fail("process not running: \(arguments[1])") }
    let application_root = AXUIElementCreateApplication(application.processIdentifier)
    // Only the menu bar extras, such as the input menu, so an item of the
    // same name in the Apple menu's recent items is never pressed
    let root: AXUIElement
    if arguments.contains("--menu-bar-extra") {
        guard let extras = attribute(application_root, "AXExtrasMenuBar") else {
            fail("no menu bar extras: \(arguments[1])", code: 5)
        }
        root = extras as! AXUIElement
    } else {
        root = application_root
    }
    if command == "ax-dump" {
        dump(root, depth: 0, limit: arguments.count > 2 ? Int(arguments[2]) ?? 6 : 6)
    } else {
        guard arguments.count >= 3,
              let element = findElement(in: root, prefix: arguments[2]) else {
            fail("element not found: \(arguments.dropFirst(2).first ?? "")", code: 5)
        }
        let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
        // Opening a menu waits while it is open and reports it cannot
        // complete; whether it opened shows in what can be pressed next
        guard result == .success || result == .cannotComplete else {
            fail("press failed: \(arguments[2]) (\(result.rawValue))")
        }
    }

case "click":
    requireFrontmost(arguments)
    let point = arguments.dropFirst().prefix(2).compactMap(Double.init)
    guard point.count == 2 else { fail("usage: click <x> <y> --expect <ids>") }
    let location = CGPoint(x: point[0], y: point[1])
    // Moved there first, so the cursor is seen reaching it
    postMouse(.mouseMoved, at: location)
    usleep(300_000)
    postMouse(.leftMouseDown, at: location)
    usleep(80_000)
    postMouse(.leftMouseUp, at: location)

case "move":
    requireFrontmost(arguments)
    let point = arguments.dropFirst().prefix(2).compactMap(Double.init)
    guard point.count == 2 else { fail("usage: move <x> <y> --expect <ids>") }
    postMouse(.mouseMoved, at: CGPoint(x: point[0], y: point[1]))

case "scroll":
    requireFrontmost(arguments)
    let values = arguments.dropFirst().prefix(3).compactMap(Double.init)
    guard values.count == 3 else { fail("usage: scroll <x> <y> <lines> --expect <ids>") }
    postMouse(.mouseMoved, at: CGPoint(x: values[0], y: values[1]))
    usleep(150_000)
    CGEvent(
        scrollWheelEvent2Source: CGEventSource(stateID: .hidSystemState),
        units: .line,
        wheelCount: 1,
        wheel1: Int32(values[2]),
        wheel2: 0,
        wheel3: 0
    )?.post(tap: .cghidEventTap)

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
