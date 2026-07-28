import CoreServices
import Foundation

struct SystemDictionaryDefinition {
    let dictionaryName: String
    let text: String
}

struct SystemDictionaryDefinitionProvider {
    private static let targetDictionaryNames = [
        "スーパー大辞林",
        "ウィズダム英和辞典 / ウィズダム和英辞典",
        "New Oxford American Dictionary"
    ]

    func definitions(for term: String) -> [SystemDictionaryDefinition] {
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

        return Self.targetDictionaryNames.compactMap { dictionaryName in
            guard let definition = definitionsByName[dictionaryName] else {
                return nil
            }
            return SystemDictionaryDefinition(
                dictionaryName: displayName(for: dictionaryName),
                text: definition
            )
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
