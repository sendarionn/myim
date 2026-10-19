@preconcurrency import AppKit
import MyIMECore

private final class TopAlignedSettingsStackView: NSStackView {
    override var isFlipped: Bool { true }
}

enum InputSourceMenuBuilder {
    struct Actions {
        let openSettings: Selector
        let openJavaScriptExtensionDirectory: Selector
        let openCandidateFilterIDSDirectory: Selector
        let manageJavaScriptExtensions: Selector
        let showStatus: Selector
    }

    static func make(actions: Actions) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        addAction(
            title: "myim設定",
            selector: actions.openSettings,
            to: menu
        )
        menu.addItem(.separator())
        addAction(
            title: "JavaScript拡張を管理",
            selector: actions.manageJavaScriptExtensions,
            to: menu
        )
        addAction(
            title: "JavaScript拡張フォルダを開く",
            selector: actions.openJavaScriptExtensionDirectory,
            to: menu
        )
        menu.addItem(.separator())
        addAction(
            title: "候補フィルターデータフォルダを開く",
            selector: actions.openCandidateFilterIDSDirectory,
            to: menu
        )
        menu.addItem(.separator())
        addAction(
            title: "状態を確認",
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
    struct ImportedDictionaryState {
        let filename: String
        let isEnabled: Bool
    }

    struct FeatureStates {
        let englishCompletion: Bool
        let appleTranslation: Bool
        let translationLanguageIdentifiers: Set<String>
        let nextInputPrediction: Bool
        let fuzzyCandidates: Bool
        let dateTimeCandidates: Bool
        let externalInformationPanel: Bool
        let systemDictionaryPreview: Bool
        let webSearch: Bool
        let importedDictionaries: [ImportedDictionaryState]
    }

    struct Actions {
        let toggleEnglishCompletion: Selector
        let toggleAppleTranslation: Selector
        let toggleTranslationLanguage: Selector
        let toggleNextInputPrediction: Selector
        let toggleFuzzyCandidates: Selector
        let toggleDateTimeCandidates: Selector
        let clearNextInputHistory: Selector
        let toggleExternalInformationPanel: Selector
        let toggleSystemDictionaryPreview: Selector
        let configureSystemDictionaries: Selector
        let toggleWebSearch: Selector
        let configureShortcuts: Selector
        let importSKKDictionary: Selector
        let toggleImportedDictionary: Selector
        let updateBasicDictionary: Selector
        let downloadCandidateFilterIDS: Selector
        let openCandidateFilterIDSDirectory: Selector
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
        panel.animationBehavior = .none
        panel.title = "myim設定"
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .normal
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

        addSection("候補", to: stack)
        addCheckboxes([
            ("英語候補を表示", actions.toggleEnglishCompletion, states.englishCompletion),
            ("次入力候補を表示", actions.toggleNextInputPrediction, states.nextInputPrediction),
            ("曖昧候補を表示", actions.toggleFuzzyCandidates, states.fuzzyCandidates),
            ("日時候補を表示", actions.toggleDateTimeCandidates, states.dateTimeCandidates)
        ], target: target, to: stack)
        addSection("翻訳", to: stack)
        addCheckboxes([
            ("翻訳候補を表示", actions.toggleAppleTranslation, states.appleTranslation)
        ], target: target, to: stack)
        addTranslationLanguageCheckboxes(
            selectedIdentifiers: states.translationLanguageIdentifiers,
            action: actions.toggleTranslationLanguage,
            target: target,
            to: stack
        )
        addSection("履歴・学習", to: stack)
        addButtons([
            ("次入力履歴を削除", actions.clearNextInputHistory)
        ], target: target, to: stack)

        addSection("外部情報", to: stack)
        addCheckboxes([
            ("外部情報パネルを表示", actions.toggleExternalInformationPanel, states.externalInformationPanel),
            ("macOS辞書パネルを表示", actions.toggleSystemDictionaryPreview, states.systemDictionaryPreview),
            ("Web検索を使用", actions.toggleWebSearch, states.webSearch)
        ], target: target, to: stack)
        addSection("辞書管理", to: stack)
        addButtons([
            ("表示するmacOS辞書", actions.configureSystemDictionaries),
            ("SKK辞書をインポート", actions.importSKKDictionary),
            ("TKGJE基本辞書を更新", actions.updateBasicDictionary)
        ], target: target, to: stack)
        for dictionary in states.importedDictionaries {
            let title = dictionary.filename.hasSuffix(".tsv")
                ? String(dictionary.filename.dropLast(4))
                : dictionary.filename
            let button = NSButton(
                checkboxWithTitle: title,
                target: target,
                action: actions.toggleImportedDictionary
            )
            button.state = dictionary.isEnabled ? .on : .off
            button.identifier = NSUserInterfaceItemIdentifier(
                dictionary.filename
            )
            stack.addArrangedSubview(button)
        }
        addSection("候補フィルター", to: stack)
        addButtons([
            ("CJKVI IDSデータをダウンロード", actions.downloadCandidateFilterIDS),
            ("データフォルダを開く", actions.openCandidateFilterIDSDirectory)
        ], target: target, to: stack)
        addSection("操作", to: stack)
        addButtons([
            ("ショートカットキーを変更", actions.configureShortcuts)
        ], target: target, to: stack)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        stack.frame = NSRect(x: 0, y: 0, width: 520, height: 1)
        stack.layoutSubtreeIfNeeded()
        stack.frame.size = NSSize(
            width: 520,
            height: max(stack.fittingSize.height, 850)
        )
        stack.autoresizingMask = [.width]
        scrollView.documentView = stack
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

    private static func addTranslationLanguageCheckboxes(
        selectedIdentifiers: Set<String>,
        action: Selector,
        target: AnyObject,
        to stack: NSStackView
    ) {
        let popup = NSPopUpButton(frame: .zero, pullsDown: true)
        let summary = NSMenuItem(
            title: "翻訳先言語（\(selectedIdentifiers.count)）",
            action: nil,
            keyEquivalent: ""
        )
        popup.menu?.addItem(summary)
        popup.menu?.addItem(.separator())
        for language in TranslationTargetLanguage.available {
            let item = NSMenuItem(
                title: language.name,
                action: action,
                keyEquivalent: ""
            )
            item.target = target
            item.representedObject = language.identifier
            item.state = selectedIdentifiers.contains(language.identifier)
                ? .on
                : .off
            popup.menu?.addItem(item)
        }
        stack.addArrangedSubview(popup)
    }

}
