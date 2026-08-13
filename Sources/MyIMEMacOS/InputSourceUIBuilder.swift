@preconcurrency import AppKit

private final class TopAlignedSettingsStackView: NSStackView {
    override var isFlipped: Bool { true }
}

enum InputSourceMenuBuilder {
    struct Actions {
        let openSettings: Selector
        let toggleTranslationMode: Selector
        let translationModeEnabled: Bool
        let syncCosenseDictionary: Selector
        let showStatus: Selector
    }

    static func make(actions: Actions) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        addAction(
            title: "myim設定…",
            selector: actions.openSettings,
            to: menu
        )
        let translationMode = NSMenuItem(
            title: "翻訳モード",
            action: actions.toggleTranslationMode,
            keyEquivalent: "t"
        )
        translationMode.target = nil
        translationMode.isEnabled = true
        translationMode.keyEquivalentModifierMask = [.option]
        translationMode.state = actions.translationModeEnabled ? .on : .off
        menu.addItem(translationMode)
        menu.addItem(.separator())
        addAction(
            title: "Cosense辞書を更新",
            selector: actions.syncCosenseDictionary,
            keyEquivalent: "r",
            modifierMask: [.command, .option, .control],
            to: menu
        )
        addAction(
            title: "状態を確認…",
            selector: actions.showStatus,
            to: menu
        )
        return menu
    }

    private static func addAction(
        title: String,
        selector: Selector,
        keyEquivalent: String = "",
        modifierMask: NSEvent.ModifierFlags = [],
        to menu: NSMenu
    ) {
        let item = NSMenuItem(
            title: title,
            action: selector,
            keyEquivalent: keyEquivalent
        )
        item.target = nil
        item.isEnabled = true
        item.keyEquivalentModifierMask = modifierMask
        menu.addItem(item)
    }
}

enum SettingsWindowBuilder {
    struct FeatureStates {
        let extensionDictionary: Bool
        let englishCompletion: Bool
        let wikipediaSuggestions: Bool
        let appleTranslation: Bool
        let nextInputPrediction: Bool
        let fuzzySuggestions: Bool
        let dateTimeCandidates: Bool
        let externalInformationPanel: Bool
        let systemDictionaryPreview: Bool
        let webSearch: Bool
    }

    struct Actions {
        let toggleExtensionDictionary: Selector
        let toggleEnglishCompletion: Selector
        let toggleWikipediaSuggestions: Selector
        let toggleAppleTranslation: Selector
        let toggleNextInputPrediction: Selector
        let toggleFuzzySuggestions: Selector
        let toggleDateTimeCandidates: Selector
        let configureDateTimeFormats: Selector
        let configureWebSearch: Selector
        let clearNextInputHistory: Selector
        let toggleExternalInformationPanel: Selector
        let toggleSystemDictionaryPreview: Selector
        let toggleWebSearch: Selector
        let configureExternalInformationPanel: Selector
        let updateBasicDictionary: Selector
        let configureCosenseProject: Selector
        let configureCosenseAuthentication: Selector
        let syncCosenseDictionary: Selector
    }

    static func make(
        target: AnyObject,
        states: FeatureStates,
        actions: Actions
    ) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 620),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "myim設定"
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.minSize = NSSize(width: 480, height: 420)

        let stack = TopAlignedSettingsStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(
            top: 18,
            left: 20,
            bottom: 18,
            right: 20
        )

        addSection("変換候補", to: stack)
        addCheckboxes([
            ("Cosense拡張辞書を使用", actions.toggleExtensionDictionary, states.extensionDictionary),
            ("英語補完を使用", actions.toggleEnglishCompletion, states.englishCompletion),
            ("Wikipediaを辞書として利用", actions.toggleWikipediaSuggestions, states.wikipediaSuggestions),
            ("日本語入力から英語の変換候補を取得", actions.toggleAppleTranslation, states.appleTranslation),
            ("次入力候補を使用", actions.toggleNextInputPrediction, states.nextInputPrediction),
            ("誤入力補完の「もしかして？」候補を表示", actions.toggleFuzzySuggestions, states.fuzzySuggestions),
            ("日時の動的候補を表示", actions.toggleDateTimeCandidates, states.dateTimeCandidates)
        ], target: target, to: stack)
        addButtons([
            ("日時候補の書式を設定…", actions.configureDateTimeFormats),
            ("Web検索先を設定…", actions.configureWebSearch),
            ("次入力履歴を削除", actions.clearNextInputHistory)
        ], target: target, to: stack)

        addSection("外部表示", to: stack)
        addCheckboxes([
            ("外部情報パネルを使用", actions.toggleExternalInformationPanel, states.externalInformationPanel),
            ("macOS辞書パネルを使用", actions.toggleSystemDictionaryPreview, states.systemDictionaryPreview),
            ("Command＋ReturnでWeb検索", actions.toggleWebSearch, states.webSearch)
        ], target: target, to: stack)
        addButtons([
            ("外部情報パネルの検索先を設定…", actions.configureExternalInformationPanel)
        ], target: target, to: stack)

        addSection("辞書管理", to: stack)
        addButtons([
            ("TKGJE基本辞書を更新", actions.updateBasicDictionary),
            ("Cosenseプロジェクトを設定…", actions.configureCosenseProject),
            ("Cosense認証を設定…", actions.configureCosenseAuthentication),
            ("Cosense辞書を更新", actions.syncCosenseDictionary)
        ], target: target, to: stack)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = stack
        stack.frame = NSRect(x: 0, y: 0, width: 520, height: 850)
        panel.contentView = scrollView
        panel.layoutIfNeeded()
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        return panel
    }

    private static func addSection(_ title: String, to stack: NSStackView) {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        stack.addArrangedSubview(label)
    }

    private static func addCheckboxes(
        _ definitions: [(String, Selector, Bool)],
        target: AnyObject,
        to stack: NSStackView
    ) {
        for (title, selector, isEnabled) in definitions {
            let button = NSButton(
                checkboxWithTitle: title,
                target: target,
                action: selector
            )
            button.state = isEnabled ? .on : .off
            stack.addArrangedSubview(button)
        }
    }

    private static func addButtons(
        _ definitions: [(String, Selector)],
        target: AnyObject,
        to stack: NSStackView
    ) {
        for (title, selector) in definitions {
            stack.addArrangedSubview(
                NSButton(title: title, target: target, action: selector)
            )
        }
    }
}
