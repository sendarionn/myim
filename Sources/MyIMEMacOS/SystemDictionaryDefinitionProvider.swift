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

    static func contentDescription(for name: String) -> String {
        let exactDescriptions = [
            "Wikipedia": "百科事典",
            "Apple Dictionary": "Apple用語辞典",
            "TTY Dictionary": "コンピュータ用語辞典",
            "现代汉语同义词典": "中国語類語辞典",
            "汉语成语词典": "中国語成語辞典",
            "现代汉语规范词典": "中国語辞典",
            "商務新詞典（全新版）": "中国語辞典",
            "五南國語活用辭典": "中国語辞典",
            "漢英對照成語詞典": "中国語→英語",
            "牛津粵英雙語詞典": "広東語↔英語",
            "英譯廣東口語詞典": "広東語→英語",
            "譯典通英漢雙向字典": "英語↔中国語",
            "牛津英汉汉英词典": "英語↔中国語",
            "超級クラウン中日辞典 / クラウン日中辞典": "中国語↔日本語",
            "뉴에이스 국어사전": "韓国語辞典",
            "뉴에이스 영한사전 / 뉴에이스 한영사전": "英語↔韓国語"
        ]
        if let description = exactDescriptions[name] {
            return description
        }
        let pairs: [(terms: [String], description: String)] = [
            (["英和", "和英"], "英語↔日本語"),
            (["英漢", "漢英"], "英語↔中国語"),
            (["英汉", "汉英"], "英語↔中国語"),
            (["English-Japanese"], "英語→日本語"),
            (["Japanese-English"], "日本語→英語"),
            (["Chinese-Japanese"], "中国語→日本語"),
            (["Japanese-Chinese"], "日本語→中国語"),
            (["英和"], "英語→日本語"),
            (["和英"], "日本語→英語"),
            (["中日"], "中国語→日本語"),
            (["中和"], "中国語→日本語"),
            (["日中"], "日本語→中国語"),
            (["和中"], "日本語→中国語"),
            (["韓日"], "韓国語→日本語"),
            (["韓和"], "韓国語→日本語"),
            (["日韓"], "日本語→韓国語"),
            (["和韓"], "日本語→韓国語"),
            (["仏和"], "フランス語→日本語"),
            (["和仏"], "日本語→フランス語"),
            (["独和"], "ドイツ語→日本語"),
            (["和独"], "日本語→ドイツ語"),
            (["西和"], "スペイン語→日本語"),
            (["和西"], "日本語→スペイン語"),
            (["伊和"], "イタリア語→日本語"),
            (["和伊"], "日本語→イタリア語"),
            (["露和"], "ロシア語→日本語"),
            (["和露"], "日本語→ロシア語")
        ]
        if let match = pairs.first(where: { pair in
            pair.terms.allSatisfy(name.localizedCaseInsensitiveContains)
        }) {
            return match.description
        }
        if name.localizedCaseInsensitiveContains("thesaurus")
            || name.contains("類語") {
            return name.localizedCaseInsensitiveContains("English")
                ? "英語類語辞典"
                : "日本語類語辞典"
        }
        if name.contains("漢和") {
            return "漢和辞典"
        }
        if name.contains("大辞林") || name.contains("広辞苑")
            || name.contains("国語") {
            return "国語辞典"
        }
        if name.localizedCaseInsensitiveContains("Dictionary of English")
            || name.localizedCaseInsensitiveContains("American Dictionary") {
            return "英英辞典"
        }
        if name.contains("汉语") || name.contains("漢語")
            || name.localizedCaseInsensitiveContains("Chinese Dictionary") {
            return "中国語辞典"
        }
        let englishMarkers = [
            "English", "Englisch", "Inglés", "Inglese", "Anglais",
            "Angol", "Engels", "İngilizce", "Англий", "英語", "英汉",
            "英漢", "英譯"
        ]
        let bilingualMarkers = [" - ", " / ", " • ", "-English", "English-"]
        if englishMarkers.contains(where: name.localizedCaseInsensitiveContains),
           bilingualMarkers.contains(where: name.localizedCaseInsensitiveContains) {
            return "英語との二言語辞典"
        }
        if name.localizedCaseInsensitiveContains("dictionary")
            || name.localizedCaseInsensitiveContains("diccionario")
            || name.localizedCaseInsensitiveContains("dizionario")
            || name.localizedCaseInsensitiveContains("ordbog")
            || name.localizedCaseInsensitiveContains("slovník")
            || name.contains("辞典") || name.contains("詞典")
            || name.contains("字典") || name.contains("사전") {
            return "単言語辞典"
        }
        return "一般辞典"
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
