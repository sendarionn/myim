@preconcurrency import AppKit

/// 入力先のアプリからフォーカスを奪わずに表示する補助パネル
final class PassiveInputPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
