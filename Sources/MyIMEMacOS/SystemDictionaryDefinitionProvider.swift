import CoreServices
import Foundation

struct SystemDictionaryDefinition {
    let dictionaryName: String
    let text: String
}

final class SystemDictionaryDefinitionProvider {
    private static let targetDictionaryNames = [
        "スーパー大辞林",
        "ウィズダム英和辞典 / ウィズダム和英辞典",
        "New Oxford American Dictionary"
    ]
    private static let maximumCacheCount = 128
    private var cachedDefinitions: [String: [SystemDictionaryDefinition]] = [:]
    private var cacheOrder: [String] = []

    func definitions(for term: String) -> [SystemDictionaryDefinition] {
        if let cached = cachedDefinitions[term] {
            return cached
        }
        guard !term.isEmpty,
              let dictionaries = DCSCopyAvailableDictionaries()?
                .takeRetainedValue() as NSArray? else {
            return []
        }

        let text = term as CFString
        let range = CFRange(
            location: 0,
            length: CFStringGetLength(text)
        )
        var definitionsByName: [String: String] = [:]

        for value in dictionaries {
            let dictionary = value as! DCSDictionary
            guard
                let dictionaryName = DCSDictionaryGetName(dictionary)?
                    .takeUnretainedValue() as String?,
                Self.targetDictionaryNames.contains(dictionaryName),
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
            Self.targetDictionaryNames.compactMap { dictionaryName in
            guard let definition = definitionsByName[dictionaryName] else {
                return nil
            }
            return SystemDictionaryDefinition(
                dictionaryName: displayName(for: dictionaryName),
                text: definition
            )
        }
        cache(definitions, for: term)
        return definitions
    }

    private func cache(
        _ definitions: [SystemDictionaryDefinition],
        for term: String
    ) {
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
