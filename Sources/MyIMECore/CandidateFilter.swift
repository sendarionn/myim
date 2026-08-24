import Foundation

public struct KanjiFilterAttributes: Equatable, Sendable {
    public let radical: Character?
    public let strokeCount: Int?
    public let components: Set<Character>

    public init(
        radical: Character? = nil,
        strokeCount: Int? = nil,
        components: Set<Character> = []
    ) {
        self.radical = radical
        self.strokeCount = strokeCount
        self.components = components
    }
}

public struct KanjiFilterDatabase: Sendable {
    private let values: [Character: KanjiFilterAttributes]

    public init(values: [Character: KanjiFilterAttributes] = [:]) {
        self.values = values
    }

    public init(text: String) {
        var values: [Character: KanjiFilterAttributes] = [:]
        for line in text.split(whereSeparator: \Character.isNewline) {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count >= 4, let kanji = fields[0].first else { continue }
            values[kanji] = KanjiFilterAttributes(
                radical: fields[1].first,
                strokeCount: Int(fields[2]),
                components: Set(fields[3])
            )
        }
        self.values = values
    }

    public func attributes(for character: Character) -> KanjiFilterAttributes? {
        values[character]
    }
}

public enum CandidateFilterCondition: Equatable, Sendable {
    case characterCount(Int)
    case contains(String)
    case kanjiOnly
    case hiraganaOnly
    case katakanaOnly
    case containsAlphanumeric
    case kanjiCount(Int)
    case radical(Character)
    case component(Character)
    case strokeCount(Int)
    case semantic(String)

    public var label: String {
        switch self {
        case let .characterCount(count): "\(count)文字"
        case let .contains(value): "「\(value)」を含む"
        case .kanjiOnly: "漢字のみ"
        case .hiraganaOnly: "ひらがなのみ"
        case .katakanaOnly: "カタカナのみ"
        case .containsAlphanumeric: "英数字を含む"
        case let .kanjiCount(count): "漢字\(count)字"
        case let .radical(value): "部首: \(value)"
        case let .component(value): "構成要素: \(value)"
        case let .strokeCount(count): "\(count)画"
        case let .semantic(query): "意味: \(query)"
        }
    }
}

public enum CandidateFilterChoice: Equatable, Sendable {
    case apply(CandidateFilterCondition)
    case remove(index: Int, label: String)

    public var label: String {
        switch self {
        case let .apply(condition): condition.label
        case let .remove(_, label): "解除: \(label)"
        }
    }
}

public struct CandidateFilterChoiceGenerator: Sendable {
    private let aliases: [String: [Character]]

    public init(aliasDictionaryText: String = "") {
        aliases = (try? DictionaryParser().parse(aliasDictionaryText)).map {
            Dictionary(uniqueKeysWithValues: $0.map { entry in
                (entry.input, entry.candidates.compactMap(\.first))
            })
        } ?? [:]
    }

    public func choices(
        for input: String,
        activeConditions: [CandidateFilterCondition]
    ) -> [CandidateFilterChoice] {
        let query = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            return activeConditions.enumerated().map {
                .remove(index: $0.offset, label: $0.element.label)
            }
        }

        var conditions: [CandidateFilterCondition] = []
        if let count = Int(query), count >= 0 {
            conditions += [.characterCount(count), .strokeCount(count)]
        }
        switch query.lowercased() {
        case "漢字", "kanji": conditions.append(.kanjiOnly)
        case "ひらがな", "hiragana": conditions.append(.hiraganaOnly)
        case "カタカナ", "katakana": conditions.append(.katakanaOnly)
        case "英数字", "alphanumeric": conditions.append(.containsAlphanumeric)
        default: break
        }
        if query.hasPrefix("漢字"), query.hasSuffix("字"),
           let count = Int(query.dropFirst(2).dropLast()) {
            conditions.append(.kanjiCount(count))
        }
        for component in aliases[query.lowercased()] ?? [] {
            conditions += [.component(component), .radical(component)]
        }
        if query.count == 1, let character = query.first {
            conditions += [.component(character), .radical(character)]
        }
        conditions += [.contains(query), .semantic(query)]

        var seen = Set<String>()
        return conditions.compactMap {
            seen.insert($0.label).inserted ? .apply($0) : nil
        }
    }
}

public struct CandidateFilter: Sendable {
    public typealias SemanticScorer = (String, String) -> Double?

    private let kanjiDatabase: KanjiFilterDatabase

    public init(kanjiDatabase: KanjiFilterDatabase = KanjiFilterDatabase()) {
        self.kanjiDatabase = kanjiDatabase
    }

    public func filtered(
        _ candidates: [String],
        conditions: [CandidateFilterCondition],
        semanticScorer: SemanticScorer? = nil
    ) -> [String] {
        let predicates = conditions.filter {
            if case .semantic = $0 { return false }
            return true
        }
        var result = candidates.filter { candidate in
            predicates.allSatisfy { matches(candidate, condition: $0) }
        }
        for condition in conditions {
            guard case let .semantic(query) = condition else { continue }
            let scores = result.map { candidate in
                (candidate, semanticScorer?(query, candidate) ?? fallbackSemanticScore(
                    query: query,
                    candidate: candidate
                ))
            }
            let ranked = scores.filter { $0.1 > 0.05 }.sorted { lhs, rhs in
                lhs.1 == rhs.1
                    ? result.firstIndex(of: lhs.0)! < result.firstIndex(of: rhs.0)!
                    : lhs.1 > rhs.1
            }
            result = ranked.map(\.0)
        }
        return result
    }

    private func matches(
        _ candidate: String,
        condition: CandidateFilterCondition
    ) -> Bool {
        switch condition {
        case let .characterCount(count): candidate.count == count
        case let .contains(value): candidate.localizedCaseInsensitiveContains(value)
        case .kanjiOnly: !candidate.isEmpty && candidate.allSatisfy(isKanji)
        case .hiraganaOnly: !candidate.isEmpty && candidate.allSatisfy(isHiragana)
        case .katakanaOnly: !candidate.isEmpty && candidate.allSatisfy(isKatakana)
        case .containsAlphanumeric: candidate.contains { $0.isASCII && $0.isLetter || $0.isNumber }
        case let .kanjiCount(count): candidate.filter(isKanji).count == count
        case let .radical(radical): candidate.contains {
            kanjiDatabase.attributes(for: $0)?.radical == radical
        }
        case let .component(component): candidate.contains {
            $0 == component
                || kanjiDatabase.attributes(for: $0)?.components.contains(component) == true
        }
        case let .strokeCount(count): candidate.contains {
            kanjiDatabase.attributes(for: $0)?.strokeCount == count
        }
        case .semantic: true
        }
    }

    private func fallbackSemanticScore(query: String, candidate: String) -> Double {
        if candidate.contains(query) || query.contains(candidate) { return 1 }
        return Set(query).intersection(Set(candidate)).isEmpty ? 0 : 0.2
    }

    private func isKanji(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy {
            (0x3400...0x4dbf).contains($0.value)
                || (0x4e00...0x9fff).contains($0.value)
                || (0xf900...0xfaff).contains($0.value)
        }
    }

    private func isHiragana(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { (0x3040...0x309f).contains($0.value) }
    }

    private func isKatakana(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy {
            (0x30a0...0x30ff).contains($0.value)
                || (0xff65...0xff9f).contains($0.value)
        }
    }
}
