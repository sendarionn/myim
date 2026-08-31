import Carbon
import Foundation

let targetIdentifier = "io.github.sendarionn.inputmethod.myime.Japanese"

func identifier(of source: TISInputSource) -> String? {
    guard let pointer = TISGetInputSourceProperty(
        source,
        kTISPropertyInputSourceID
    ) else {
        return nil
    }
    return Unmanaged<CFString>
        .fromOpaque(pointer)
        .takeUnretainedValue() as String
}

func modeIdentifier(of source: TISInputSource) -> String? {
    guard let pointer = TISGetInputSourceProperty(
        source,
        kTISPropertyInputModeID
    ) else {
        return nil
    }
    return Unmanaged<CFString>
        .fromOpaque(pointer)
        .takeUnretainedValue() as String
}

func source(
    with sourceIdentifier: String,
    includeAllInstalled: Bool = true
) -> TISInputSource? {
    let sources = TISCreateInputSourceList(
        nil,
        includeAllInstalled
    ).takeRetainedValue()
        as! [TISInputSource]
    return sources.first { identifier(of: $0) == sourceIdentifier }
}

let command = CommandLine.arguments.dropFirst().first ?? "registered"
switch command {
case "registered":
    print(source(with: targetIdentifier) == nil ? "0" : "1")
case "enabled":
    print(
        source(
            with: targetIdentifier,
            includeAllInstalled: false
        ) == nil ? "0" : "1"
    )
case "mode-id":
    guard let target = source(with: targetIdentifier) else {
        exit(1)
    }
    print(modeIdentifier(of: target) ?? "")
case "selected":
    let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    print(identifier(of: current) == targetIdentifier ? "1" : "0")
case "selected-fallback":
    let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    print(identifier(of: current) == "com.apple.keylayout.ABC" ? "1" : "0")
case "current":
    let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    print(identifier(of: current) ?? "")
    print(modeIdentifier(of: current) ?? "")
case "select-fallback":
    guard let fallback = source(with: "com.apple.keylayout.ABC") else {
        fatalError("ABC入力ソースが見つかりません")
    }
    guard TISSelectInputSource(fallback) == noErr else {
        fatalError("ABC入力ソースへ切り替えられません")
    }
case "select-myim":
    guard let target = source(with: targetIdentifier) else {
        exit(1)
    }
    guard TISSelectInputSource(target) == noErr else {
        exit(1)
    }
default:
    fatalError("不明な操作: \(command)")
}
