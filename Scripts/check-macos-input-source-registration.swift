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

func source(with sourceIdentifier: String) -> TISInputSource? {
    let sources = TISCreateInputSourceList(nil, true).takeRetainedValue()
        as! [TISInputSource]
    return sources.first { identifier(of: $0) == sourceIdentifier }
}

let command = CommandLine.arguments.dropFirst().first ?? "registered"
switch command {
case "registered":
    print(source(with: targetIdentifier) == nil ? "0" : "1")
case "selected":
    let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    print(identifier(of: current) == targetIdentifier ? "1" : "0")
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
