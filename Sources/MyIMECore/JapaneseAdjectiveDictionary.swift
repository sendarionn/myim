public enum JapaneseAdjectiveClass: String, CaseIterable, Sendable {
    case naAdjectiveStem = "na-adjective-stem"
    case iAdjective = "i-adjective"
}

/// The adjective entries extracted from the same Mozc source revision as
/// the bundled conversion dictionary
public struct JapaneseAdjectiveDictionary: Sendable {
    private struct ReadingClassKey: Hashable, Sendable {
        let reading: String
        let adjectiveClass: JapaneseAdjectiveClass
    }

    private struct Key: Hashable, Sendable {
        let reading: String
        let surface: String
        let adjectiveClass: JapaneseAdjectiveClass
    }

    private let entries: Set<Key>
    private let surfacesByReadingAndClass: [ReadingClassKey: [String]]

    public init(text: String = "") {
        let parsedEntries: [Key] = text.split(
            whereSeparator: \.isNewline
        ).compactMap {
            line in
            let columns = line.split(separator: "\t")
            guard columns.count == 4,
                  let adjectiveClass = JapaneseAdjectiveClass(
                    rawValue: String(columns[2])
                  ),
                  Int(columns[3]) != nil else {
                return nil
            }
            return Key(
                reading: String(columns[0]),
                surface: String(columns[1]),
                adjectiveClass: adjectiveClass
            )
        }
        entries = Set(parsedEntries)
        var grouped: [ReadingClassKey: [String]] = [:]
        for entry in parsedEntries {
            let key = ReadingClassKey(
                reading: entry.reading,
                adjectiveClass: entry.adjectiveClass
            )
            if grouped[key]?.contains(entry.surface) != true {
                grouped[key, default: []].append(entry.surface)
            }
        }
        surfacesByReadingAndClass = grouped
    }

    public func contains(
        reading: String,
        surface: String,
        class adjectiveClass: JapaneseAdjectiveClass
    ) -> Bool {
        entries.contains(Key(
            reading: reading,
            surface: surface,
            adjectiveClass: adjectiveClass
        ))
    }

    public func containsAny(reading: String, surface: String) -> Bool {
        JapaneseAdjectiveClass.allCases.contains {
            contains(reading: reading, surface: surface, class: $0)
        }
    }

    public func surfaces(
        reading: String,
        class adjectiveClass: JapaneseAdjectiveClass
    ) -> [String] {
        surfacesByReadingAndClass[
            ReadingClassKey(
                reading: reading,
                adjectiveClass: adjectiveClass
            )
        ] ?? []
    }
}
