import AppKit

enum MyIMFeatureShortcut: String, CaseIterable {
    case candidateFilter
    case calendar
    case emoji
    case dictionaryRegistration
    case translationMode
    case webSearch
    case externalInformation

    var title: String {
        switch self {
        case .candidateFilter: "候補フィルター"
        case .calendar: "カレンダー"
        case .emoji: "絵文字パネル"
        case .dictionaryRegistration: "辞書登録"
        case .translationMode: "翻訳モード"
        case .webSearch: "Web検索"
        case .externalInformation: "外部ページ"
        }
    }

    var defaultShortcut: MyIMShortcut {
        switch self {
        case .candidateFilter: MyIMShortcut(modifiers: [.option], key: "f")
        case .calendar: MyIMShortcut(modifiers: [.option], key: "c")
        case .emoji: MyIMShortcut(modifiers: [.option], key: "e")
        case .dictionaryRegistration: MyIMShortcut(modifiers: [.option], key: "d")
        case .translationMode: MyIMShortcut(modifiers: [.option], key: "t")
        case .webSearch: MyIMShortcut(modifiers: [.command], key: "return")
        case .externalInformation: MyIMShortcut(modifiers: [.command], key: "o")
        }
    }

    var defaultsKey: String { "FeatureShortcut.\(rawValue)" }

    var shortcut: MyIMShortcut {
        guard let value = UserDefaults.standard.string(forKey: defaultsKey),
              let shortcut = MyIMShortcut(storageValue: value) else {
            return defaultShortcut
        }
        return shortcut
    }

    func save(_ shortcut: MyIMShortcut) {
        UserDefaults.standard.set(shortcut.storageValue, forKey: defaultsKey)
    }

    func reset() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}

struct MyIMShortcut {
    let modifiers: NSEvent.ModifierFlags
    let key: String

    init(modifiers: NSEvent.ModifierFlags, key: String) {
        self.modifiers = modifiers
        self.key = key.lowercased()
    }

    init?(storageValue: String) {
        let parts = storageValue.split(separator: "+").map(String.init)
        guard let key = parts.last, !key.isEmpty else { return nil }
        var modifiers: NSEvent.ModifierFlags = []
        for part in parts.dropLast() {
            switch part {
            case "command": modifiers.insert(.command)
            case "option": modifiers.insert(.option)
            case "control": modifiers.insert(.control)
            case "shift": modifiers.insert(.shift)
            default: return nil
            }
        }
        self.init(modifiers: modifiers, key: key)
    }

    init?(event: NSEvent) {
        let modifiers = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad])
        guard !modifiers.intersection([.command, .option, .control]).isEmpty,
              let key = Self.keyName(for: event) else {
            return nil
        }
        self.init(modifiers: modifiers, key: key)
    }

    var storageValue: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("control") }
        if modifiers.contains(.option) { parts.append("option") }
        if modifiers.contains(.shift) { parts.append("shift") }
        if modifiers.contains(.command) { parts.append("command") }
        parts.append(key)
        return parts.joined(separator: "+")
    }

    var displayName: String {
        var value = ""
        if modifiers.contains(.control) { value += "⌃" }
        if modifiers.contains(.option) { value += "⌥" }
        if modifiers.contains(.shift) { value += "⇧" }
        if modifiers.contains(.command) { value += "⌘" }
        let keyLabels = [
            "return": "↩", "tab": "Tab", "space": "Space",
            "delete": "⌫", "escape": "Esc", "left": "←",
            "right": "→", "down": "↓", "up": "↑"
        ]
        value += keyLabels[key] ?? key.uppercased()
        return value
    }

    func matches(_ event: NSEvent) -> Bool {
        let eventModifiers = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad])
        guard eventModifiers == modifiers else { return false }
        return Self.keyName(for: event) == key
    }

    private static func keyName(for event: NSEvent) -> String? {
        let specialKeys: [UInt16: String] = [
            36: "return", 76: "return", 48: "tab", 49: "space",
            51: "delete", 53: "escape", 123: "left", 124: "right",
            125: "down", 126: "up", 122: "f1", 120: "f2",
            99: "f3", 118: "f4", 96: "f5", 97: "f6", 98: "f7",
            100: "f8", 101: "f9", 109: "f10", 103: "f11", 111: "f12"
        ]
        if let special = specialKeys[event.keyCode] { return special }
        let ansiKeys: [UInt16: String] = [
            0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g",
            6: "z", 7: "x", 8: "c", 9: "v", 11: "b", 12: "q",
            13: "w", 14: "e", 15: "r", 16: "y", 17: "t", 18: "1",
            19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 25: "9",
            26: "7", 28: "8", 29: "0", 31: "o", 32: "u", 34: "i",
            35: "p", 37: "l", 38: "j", 40: "k", 45: "n", 46: "m"
        ]
        if let ansiKey = ansiKeys[event.keyCode] { return ansiKey }
        guard let characters = event.charactersIgnoringModifiers?.lowercased(),
              characters.count == 1 else {
            return nil
        }
        return characters
    }
}
