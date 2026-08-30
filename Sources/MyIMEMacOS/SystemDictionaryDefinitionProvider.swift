import CoreServices
import Foundation

struct SystemDictionaryDefinition {
    let dictionaryName: String
    let text: String
}

final class SystemDictionaryDefinitionProvider: @unchecked Sendable {
    static let defaultDictionaryNames = [
        "スーパー大辞林",
        "ウィズダム英和辞典 / ウィズダム和英辞典",
        "New Oxford American Dictionary"
    ]
    private static let maximumCacheCount = 128
    private let availableDictionaries: [(name: String, dictionary: DCSDictionary)]
    private let dictionariesByName: [String: DCSDictionary]
    private let cacheLock = NSLock()
    private var cachedDefinitions: [String: [SystemDictionaryDefinition]] = [:]
    private var cacheOrder: [String] = []

    init() {
        let dictionaries = Self.loadAvailableDictionaries()
        availableDictionaries = dictionaries
        dictionariesByName = dictionaries.reduce(into: [:]) {
            $0[$1.name] = $1.dictionary
        }
    }

    func availableDictionaryNames() -> [String] {
        availableDictionaries.map(\.name)
    }

    func contentDescriptions() -> [String: String] {
        Self.loadDictionaryMetadataDescriptions(
            for: availableDictionaryNames()
        )
    }

    private static func loadAvailableDictionaries()
        -> [(name: String, dictionary: DCSDictionary)] {
        guard let dictionaries = DCSCopyAvailableDictionaries()?
            .takeRetainedValue() as NSArray? else { return [] }
        return dictionaries.compactMap { value in
            let cfValue = value as CFTypeRef
            guard CFGetTypeID(cfValue) == DCSDictionaryGetTypeID() else {
                return nil
            }
            let dictionary = value as! DCSDictionary
            guard let name = DCSDictionaryGetName(dictionary)?
                .takeUnretainedValue() as String? else { return nil }
            return (name, dictionary)
        }
    }

    private static func loadDictionaryMetadataDescriptions(
        for names: [String]
    ) -> [String: String] {
        var descriptions = builtInDictionaryDescriptions
        let catalogs = [
            "/System/Library/AssetsV2/com_apple_MobileAsset_DictionaryServices_dictionary3macOS/com_apple_MobileAsset_DictionaryServices_dictionary3macOS.xml",
            "/System/Library/AssetsV2/com_apple_MobileAsset_DictionaryServices_dictionaryOSX/com_apple_MobileAsset_DictionaryServices_dictionaryOSX.xml"
        ]
        for catalog in catalogs {
            descriptions.merge(
                dictionaryCatalogDescriptions(at: URL(fileURLWithPath: catalog))
            ) { current, _ in current }
        }
        let roots = [
            "/System/Library/AssetsV2/com_apple_MobileAsset_DictionaryServices_dictionary3macOS",
            "/Library/Dictionaries",
            NSString(string: "~/Library/Dictionaries").expandingTildeInPath
        ]
        let keys: [URLResourceKey] = [.isDirectoryKey]
        for root in roots {
            guard let enumerator = FileManager.default.enumerator(
                at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            ) else { continue }
            for case let url as URL in enumerator where url.pathExtension == "dictionary" {
                enumerator.skipDescendants()
                guard let metadata = dictionaryMetadata(at: url) else { continue }
                descriptions[metadata.name] = metadata.description
            }
        }
        return names.reduce(into: [:]) { result, name in
            result[name] = descriptions[name] ?? contentDescriptionFromName(name)
        }
    }

    private static func dictionaryCatalogDescriptions(
        at catalogURL: URL
    ) -> [String: String] {
        guard let data = try? Data(contentsOf: catalogURL),
              let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: 0,
                format: nil
              ) as? [String: Any],
              let assets = plist["Assets"] as? [[String: Any]]
        else { return [:] }
        return assets.reduce(into: [:]) { result, asset in
            guard let name = asset["DictionaryPackageDisplayName"] as? String,
                  let identifiers = asset["IndexLanguages"] as? [String]
            else { return }
            let languages = identifiers.compactMap(localizedLanguageName)
                .reduce(into: [String]()) { values, language in
                    if !values.contains(language) { values.append(language) }
                }
            guard !languages.isEmpty else { return }
            result[name] = languages.joined(separator: " - ")
        }
    }

    private static func dictionaryMetadata(
        at dictionaryURL: URL
    ) -> (name: String, description: String)? {
        let infoURL = dictionaryURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoURL),
              let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: 0,
                format: nil
              ) as? [String: Any],
              let name = plist["CFBundleDisplayName"] as? String
        else { return nil }
        if let formalName = plist["CFBundleName"] as? String,
           let description = localizedMetadataDescription(formalName) {
            return (name, description)
        }
        guard let languages = plist["DCSDictionaryLanguages"] as? [[String: Any]] else {
            return nil
        }
        let identifiers = languages.compactMap {
            $0["DCSDictionaryIndexLanguage"] as? String
        }
        let localized = identifiers.compactMap(localizedLanguageName)
            .reduce(into: [String]()) { values, language in
                if !values.contains(language) { values.append(language) }
            }
        guard !localized.isEmpty else { return nil }
        return (name, localized.joined(separator: " - "))
    }

    private static func localizedMetadataDescription(
        _ description: String
    ) -> String? {
        if description == "English Thesaurus" { return "英語類語" }
        let languages = description.components(separatedBy: " - ")
            .compactMap { metadataLanguageNames[$0] }
        guard !languages.isEmpty else { return nil }
        return languages.joined(separator: " - ")
    }

    private static func localizedLanguageName(_ identifier: String) -> String? {
        let normalized = identifier.replacingOccurrences(of: "-", with: "_")
        if normalized == "zh_CN" || normalized == "zh_Hans" {
            return "簡体字中国語"
        }
        if normalized == "zh_TW" || normalized == "zh_HK"
            || normalized == "zh_Hant" {
            return "繁体字中国語"
        }
        guard identifier != "*" else { return nil }
        let languageCode = normalized.split(separator: "_").first.map(String.init)
        guard let languageCode else { return nil }
        return Locale(identifier: "ja").localizedString(forLanguageCode: languageCode)
    }

    private static let metadataLanguageNames = [
        "Japanese": "日本語",
        "English": "英語",
        "Simplified Chinese": "簡体字中国語",
        "Traditional Chinese": "繁体字中国語",
        "German": "ドイツ語",
        "Indonesian": "インドネシア語",
        "Korean": "韓国語",
        "French": "フランス語",
        "Spanish": "スペイン語",
        "Italian": "イタリア語",
        "Russian": "ロシア語",
        "Portuguese": "ポルトガル語",
        "Dutch": "オランダ語",
        "Arabic": "アラビア語",
        "Hindi": "ヒンディー語",
        "Thai": "タイ語",
        "Vietnamese": "ベトナム語"
    ]

    private static let builtInDictionaryDescriptions = [
        "Wikipedia": "日本語",
        "Apple Dictionary": "英語",
        "TTY Dictionary": "英語"
    ]

    private static func contentDescriptionFromName(_ name: String) -> String {
        let exactDescriptions = [
            "Wikipedia": "日本語",
            "Apple Dictionary": "英語",
            "TTY Dictionary": "英語",
            "现代汉语同义词典": "簡体字中国語",
            "汉语成语词典": "簡体字中国語",
            "现代汉语规范词典": "簡体字中国語",
            "商務新詞典（全新版）": "繁体字中国語",
            "五南國語活用辭典": "繁体字中国語",
            "漢英對照成語詞典": "繁体字中国語 - 英語",
            "牛津粵英雙語詞典": "広東語 - 英語",
            "英譯廣東口語詞典": "広東語 - 英語",
            "譯典通英漢雙向字典": "繁体字中国語 - 英語",
            "牛津英汉汉英词典": "簡体字中国語 - 英語",
            "超級クラウン中日辞典 / クラウン日中辞典": "簡体字中国語 - 日本語",
            "ウィズダム英和辞典 / ウィズダム和英辞典": "日本語 - 英語",
            "スーパー大辞林": "日本語",
            "New Oxford American Dictionary": "英語",
            "Oxford American Writer’s Thesaurus": "英語",
            "뉴에이스 국어사전": "韓国語",
            "뉴에이스 영한사전 / 뉴에이스 한영사전": "韓国語 - 英語"
        ]
        if let description = exactDescriptions[name] {
            return description
        }
        let pairs: [(terms: [String], description: String)] = [
            (["英和", "和英"], "日本語 - 英語"),
            (["英漢", "漢英"], "中国語 - 英語"),
            (["英汉", "汉英"], "簡体字中国語 - 英語"),
            (["English-Japanese"], "日本語 - 英語"),
            (["Japanese-English"], "日本語 - 英語"),
            (["Chinese-Japanese"], "中国語 - 日本語"),
            (["Japanese-Chinese"], "日本語 - 中国語"),
            (["英和"], "英語 - 日本語"),
            (["和英"], "日本語 - 英語"),
            (["中日"], "中国語 - 日本語"),
            (["中和"], "中国語 - 日本語"),
            (["日中"], "日本語 - 中国語"),
            (["和中"], "日本語 - 中国語"),
            (["韓日"], "韓国語 - 日本語"),
            (["韓和"], "韓国語 - 日本語"),
            (["日韓"], "日本語 - 韓国語"),
            (["和韓"], "日本語 - 韓国語"),
            (["仏和"], "フランス語 - 日本語"),
            (["和仏"], "日本語 - フランス語"),
            (["独和"], "ドイツ語 - 日本語"),
            (["和独"], "日本語 - ドイツ語"),
            (["西和"], "スペイン語 - 日本語"),
            (["和西"], "日本語 - スペイン語"),
            (["伊和"], "イタリア語 - 日本語"),
            (["和伊"], "日本語 - イタリア語"),
            (["露和"], "ロシア語 - 日本語"),
            (["和露"], "日本語 - ロシア語")
        ]
        if let match = pairs.first(where: { pair in
            pair.terms.allSatisfy(name.localizedCaseInsensitiveContains)
        }) {
            return match.description
        }
        if name.localizedCaseInsensitiveContains("thesaurus")
            || name.contains("類語") {
            return name.localizedCaseInsensitiveContains("English")
                ? "英語"
                : "日本語"
        }
        if name.contains("漢和") {
            return "日本語"
        }
        if name.contains("大辞林") || name.contains("広辞苑")
            || name.contains("国語") {
            return "日本語"
        }
        if name.localizedCaseInsensitiveContains("Dictionary of English")
            || name.localizedCaseInsensitiveContains("American Dictionary") {
            return "英語"
        }
        if name.contains("汉语") || name.contains("漢語")
            || name.localizedCaseInsensitiveContains("Chinese Dictionary") {
            return "中国語"
        }
        let englishMarkers = [
            "English", "Englisch", "Inglés", "Inglese", "Anglais",
            "Angol", "Engels", "İngilizce", "Англий", "英語", "英汉",
            "英漢", "英譯"
        ]
        let bilingualMarkers = [" - ", " / ", " • ", "-English", "English-"]
        if englishMarkers.contains(where: name.localizedCaseInsensitiveContains),
           bilingualMarkers.contains(where: name.localizedCaseInsensitiveContains) {
            return "英語 - その他の言語"
        }
        if name.localizedCaseInsensitiveContains("dictionary")
            || name.localizedCaseInsensitiveContains("diccionario")
            || name.localizedCaseInsensitiveContains("dizionario")
            || name.localizedCaseInsensitiveContains("ordbog")
            || name.localizedCaseInsensitiveContains("slovník")
            || name.contains("辞典") || name.contains("詞典")
            || name.contains("字典") || name.contains("사전") {
            return "単一言語"
        }
        return "辞書"
    }

    func definitions(
        for term: String,
        dictionaryNames: [String]
    ) -> [SystemDictionaryDefinition] {
        let cacheKey = dictionaryNames.joined(separator: "\u{1F}") + "\u{1E}" + term
        cacheLock.lock()
        let cached = cachedDefinitions[cacheKey]
        cacheLock.unlock()
        if let cached {
            return cached
        }
        guard !term.isEmpty else {
            return []
        }

        let text = term as CFString
        let range = CFRange(
            location: 0,
            length: CFStringGetLength(text)
        )
        var definitionsByName: [String: String] = [:]

        for dictionaryName in dictionaryNames {
            guard
                let dictionary = dictionariesByName[dictionaryName],
                let definition = DCSCopyTextDefinition(
                    dictionary,
                    text,
                    range
                )?.takeRetainedValue() as String?
            else {
                continue
            }

            definitionsByName[dictionaryName] = definition
        }

        let definitions: [SystemDictionaryDefinition] =
            dictionaryNames.compactMap { dictionaryName in
            guard let definition = definitionsByName[dictionaryName] else {
                return nil
            }
            return SystemDictionaryDefinition(
                dictionaryName: displayName(for: dictionaryName),
                text: definition
            )
        }
        cache(definitions, for: cacheKey)
        return definitions
    }

    func clearCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cachedDefinitions.removeAll()
        cacheOrder.removeAll()
    }

    private func cache(
        _ definitions: [SystemDictionaryDefinition],
        for term: String
    ) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cachedDefinitions[term] = definitions
        cacheOrder.removeAll { $0 == term }
        cacheOrder.append(term)
        while cacheOrder.count > Self.maximumCacheCount {
            cachedDefinitions.removeValue(forKey: cacheOrder.removeFirst())
        }
    }

    private func displayName(for dictionaryName: String) -> String {
        if dictionaryName == "ウィズダム英和辞典 / ウィズダム和英辞典" {
            return "ウィズダム英和辞典・ウィズダム和英辞典"
        }
        return dictionaryName
    }
}

@_silgen_name("DCSCopyAvailableDictionaries")
private func DCSCopyAvailableDictionaries() -> Unmanaged<CFArray>?

@_silgen_name("DCSDictionaryGetName")
private func DCSDictionaryGetName(
    _ dictionary: DCSDictionary
) -> Unmanaged<CFString>?

@_silgen_name("DCSDictionaryGetTypeID")
private func DCSDictionaryGetTypeID() -> CFTypeID
