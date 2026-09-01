import AppKit

struct TranslationTargetLanguage: Equatable {
    let identifier: String
    let name: String

    static let defaultsKey = "TranslationTargetLanguage"
    static let defaultLanguage = TranslationTargetLanguage(
        identifier: "en",
        name: "英語"
    )
    static let available: [TranslationTargetLanguage] = [
        .init(identifier: "en", name: "英語"),
        .init(identifier: "zh-Hans", name: "中国語（簡体字）"),
        .init(identifier: "zh-Hant", name: "中国語（繁体字）"),
        .init(identifier: "ko", name: "韓国語"),
        .init(identifier: "fr", name: "フランス語"),
        .init(identifier: "de", name: "ドイツ語"),
        .init(identifier: "es", name: "スペイン語"),
        .init(identifier: "it", name: "イタリア語"),
        .init(identifier: "pt-BR", name: "ポルトガル語（ブラジル）"),
        .init(identifier: "nl", name: "オランダ語"),
        .init(identifier: "pl", name: "ポーランド語"),
        .init(identifier: "ru", name: "ロシア語"),
        .init(identifier: "uk", name: "ウクライナ語"),
        .init(identifier: "tr", name: "トルコ語"),
        .init(identifier: "ar", name: "アラビア語"),
        .init(identifier: "th", name: "タイ語"),
        .init(identifier: "vi", name: "ベトナム語"),
        .init(identifier: "id", name: "インドネシア語")
    ]

    static var current: TranslationTargetLanguage {
        guard let identifier = UserDefaults.standard.string(forKey: defaultsKey),
              let language = available.first(where: { $0.identifier == identifier }) else {
            return defaultLanguage
        }
        return language
    }
}

final class TranslationLanguageSettingsController: NSObject {
    private var panel: NSPanel?

    func show() {
        if let panel {
            selectCurrentLanguage(in: panel)
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            return
        }
        let panel = makePanel()
        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 110),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "翻訳先の言語"
        panel.isReleasedWhenClosed = false
        let popup = NSPopUpButton(frame: NSRect(x: 20, y: 35, width: 320, height: 30))
        popup.removeAllItems()
        for language in TranslationTargetLanguage.available {
            let item = NSMenuItem(title: language.name, action: nil, keyEquivalent: "")
            item.representedObject = language.identifier
            popup.menu?.addItem(item)
        }
        popup.target = self
        popup.action = #selector(languageChanged(_:))
        panel.contentView = popup
        selectCurrentLanguage(in: panel)
        return panel
    }

    private func selectCurrentLanguage(in panel: NSPanel) {
        guard let popup = panel.contentView as? NSPopUpButton else { return }
        popup.selectItem(withTitle: TranslationTargetLanguage.current.name)
    }

    @objc private func languageChanged(_ sender: NSPopUpButton) {
        guard let identifier = sender.selectedItem?.representedObject as? String else { return }
        UserDefaults.standard.set(identifier, forKey: TranslationTargetLanguage.defaultsKey)
    }
}
