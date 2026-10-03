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

    public init(text: String, supplementalIDSTexts: [String]) {
        var base = KanjiFilterDatabase(text: text).values
        let supplemental = KanjiIDSComponentParser.components(
            from: supplementalIDSTexts
        )
        for (character, components) in supplemental {
            let current = base[character] ?? KanjiFilterAttributes()
            base[character] = KanjiFilterAttributes(
                radical: current.radical,
                strokeCount: current.strokeCount,
                components: current.components.union(components)
            )
        }
        values = base
    }

    public func attributes(for character: Character) -> KanjiFilterAttributes? {
        values[character]
    }
}

public enum KanjiIDSComponentParser {
    public static func components(from texts: [String]) -> [Character: Set<Character>] {
        var direct: [Character: Set<Character>] = [:]
        for text in texts {
            for rawLine in text.split(whereSeparator: \Character.isNewline) {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                guard !line.isEmpty, !line.hasPrefix("#") else { continue }
                let fields = line.split(
                    omittingEmptySubsequences: true,
                    whereSeparator: { $0 == "\t" || $0 == " " }
                )
                guard fields.count >= 3,
                      fields[0].hasPrefix("U+"),
                      let target = fields[1].first else { continue }
                let description = fields.dropFirst(2).joined(separator: " ")
                    .replacingOccurrences(
                        of: #"&[^;]+;|\[[^\]]+\]"#,
                        with: "",
                        options: .regularExpression
                    )
                let values = Set(description.filter {
                    $0 != target && isComponentCharacter($0)
                })
                if !values.isEmpty {
                    direct[target, default: []].formUnion(values)
                }
            }
        }

        var expanded: [Character: Set<Character>] = [:]
        func resolve(_ character: Character, visiting: Set<Character>) -> Set<Character> {
            if let cached = expanded[character] { return cached }
            guard !visiting.contains(character) else { return [] }
            var nextVisiting = visiting
            nextVisiting.insert(character)
            var result = direct[character] ?? []
            for component in Array(result) {
                result.formUnion(resolve(component, visiting: nextVisiting))
            }
            result.remove(character)
            expanded[character] = result
            return result
        }
        for character in direct.keys {
            _ = resolve(character, visiting: [])
        }
        return expanded
    }

    private static func isComponentCharacter(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { scalar in
            let value = scalar.value
            if (0x2ff0...0x2fff).contains(value) || value == 0x303e {
                return false
            }
            return (0x2e80...0x2fdf).contains(value)
                || (0x31c0...0x31ef).contains(value)
                || (0x3400...0x4dbf).contains(value)
                || (0x4e00...0x9fff).contains(value)
                || (0xf900...0xfaff).contains(value)
                || (0x20000...0x323af).contains(value)
        }
    }
}

public enum KanjiRadicalNormalizer {
    private static let canonicalByVariant: [Character: Character] = [
        "亻": "人",
        "氵": "水",
        "氺": "水",
        "扌": "手",
        "忄": "心",
        "㣺": "心",
        "灬": "火",
        "艹": "艸",
        "礻": "示",
        "衤": "衣",
        "犭": "犬",
        "刂": "刀",
        "攵": "攴",
        "辶": "辵",
        "飠": "食"
    ]

    public static func canonical(_ radical: Character) -> Character {
        canonicalByVariant[radical] ?? radical
    }
}

public enum CandidateFilterInputConfirmationPolicy {
    public static func canConfirmDirectly(
        input: String,
        queryVariants: [String]
    ) -> Bool {
        !input.isEmpty && queryVariants == [input]
    }
}

public enum CandidateFilterArrowNavigation {
    public static func offset(forKeyCode keyCode: Int) -> Int? {
        switch keyCode {
        case 124, 125: 1
        case 123, 126: -1
        default: nil
        }
    }

    public static func offset(forCommand command: String) -> Int? {
        switch command {
        case "moveRight:", "moveDown:": 1
        case "moveLeft:", "moveUp:": -1
        default: nil
        }
    }
}

public enum CandidateFilterLearning {
    public static func reading(for filterInput: String) -> String? {
        let reading = filterInput.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return reading.isEmpty ? nil : reading
    }
}

public struct CandidateFilterPanelRect: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct CandidateFilterPanelPoint: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public enum CandidateFilterPanelPlacement {
    public static func origin(
        beside anchor: CandidateFilterPanelRect,
        panelWidth: Double,
        panelHeight: Double,
        visibleFrame: CandidateFilterPanelRect,
        spacing: Double = 8
    ) -> CandidateFilterPanelPoint {
        let anchorMaxX = anchor.x + anchor.width
        let anchorMaxY = anchor.y + anchor.height
        let visibleMaxX = visibleFrame.x + visibleFrame.width
        let visibleMaxY = visibleFrame.y + visibleFrame.height
        let rightX = anchorMaxX + spacing
        let leftX = anchor.x - spacing - panelWidth
        let x = rightX + panelWidth <= visibleMaxX
            ? rightX
            : max(leftX, visibleFrame.x)
        let alignedY = anchorMaxY - panelHeight
        let y = min(
            max(alignedY, visibleFrame.y),
            visibleMaxY - panelHeight
        )
        return CandidateFilterPanelPoint(x: x, y: y)
    }
}

public enum HorizontalPanelGroupPlacement {
    public static func offset(
        groupMinX: Double,
        groupMaxX: Double,
        visibleMinX: Double,
        visibleMaxX: Double,
        reservedLeftWidth: Double = 0,
        reservedRightWidth: Double = 0
    ) -> Double {
        let reservedGroupMinX = groupMinX - max(reservedLeftWidth, 0)
        let reservedGroupMaxX = groupMaxX + max(reservedRightWidth, 0)
        let groupWidth = reservedGroupMaxX - reservedGroupMinX
        let visibleWidth = visibleMaxX - visibleMinX
        guard groupWidth <= visibleWidth else {
            return visibleMinX - reservedGroupMinX
        }
        if reservedGroupMinX < visibleMinX {
            return visibleMinX - reservedGroupMinX
        }
        if reservedGroupMaxX > visibleMaxX {
            return visibleMaxX - reservedGroupMaxX
        }
        return 0
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

public enum CandidateFilterDraftStage: Equatable, Sendable {
    case conversion
    case filter
}

public enum CandidateFilterDraftChoice: Equatable, Sendable {
    case input(String)
    case filter(CandidateFilterChoice)

    public var label: String {
        switch self {
        case let .input(value): value
        case let .filter(choice): choice.label
        }
    }
}

public struct CandidateFilterDraft: Equatable, Sendable {
    public private(set) var input = ""
    public private(set) var stage = CandidateFilterDraftStage.conversion
    public private(set) var choices: [CandidateFilterDraftChoice] = []
    public private(set) var selectedIndex: Int?

    public init() {}

    mutating func append(_ value: String) {
        stage = .conversion
        input.append(contentsOf: value)
        selectedIndex = nil
    }

    @discardableResult
    mutating func deleteBackward() -> Bool {
        guard stage == .conversion, !input.isEmpty else { return false }
        input.removeLast()
        selectedIndex = nil
        return true
    }

    mutating func enterFilterStage(input: String? = nil) {
        if let input {
            self.input = input
        }
        stage = .filter
        selectedIndex = nil
    }

    mutating func returnToConversionStage() {
        stage = .conversion
        selectedIndex = nil
    }

    mutating func replaceChoices(_ choices: [CandidateFilterDraftChoice]) {
        self.choices = choices
        if let selectedIndex, !choices.indices.contains(selectedIndex) {
            self.selectedIndex = nil
        }
    }

    @discardableResult
    mutating func moveSelection(by offset: Int) -> Bool {
        guard !choices.isEmpty else { return false }
        let initialIndex = offset > 0 ? -1 : 0
        selectedIndex = (
            (selectedIndex ?? initialIndex) + offset + choices.count
        ) % choices.count
        return true
    }
}

public enum CandidateFilterSelectionResult: Equatable, Sendable {
    case convertedInput(value: String, reading: String)
    case conditionsChanged
}

public struct CandidateFilterInputSession: Equatable, Sendable {
    public private(set) var conditions: [CandidateFilterCondition] = []
    public private(set) var draft: CandidateFilterDraft?

    public init() {}

    public mutating func beginDraft() {
        draft = CandidateFilterDraft()
    }

    public mutating func appendToDraft(_ value: String) {
        draft?.append(value)
    }

    @discardableResult
    public mutating func deleteBackwardFromDraft() -> Bool {
        draft?.deleteBackward() ?? false
    }

    public mutating func enterFilterStage() {
        draft?.enterFilterStage()
    }

    @discardableResult
    public mutating func returnToConversionStage() -> Bool {
        guard draft?.stage == .filter else { return false }
        draft?.returnToConversionStage()
        return true
    }

    public mutating func updateDraftChoices(
        _ choices: [CandidateFilterDraftChoice]
    ) {
        draft?.replaceChoices(choices)
    }

    @discardableResult
    public mutating func moveDraftSelection(by offset: Int) -> Bool {
        draft?.moveSelection(by: offset) ?? false
    }

    public mutating func applySelectedChoice()
        -> CandidateFilterSelectionResult? {
        guard let draft,
              let selectedIndex = draft.selectedIndex,
              draft.choices.indices.contains(selectedIndex) else {
            return nil
        }
        switch draft.choices[selectedIndex] {
        case let .input(value):
            let reading = draft.input
            self.draft?.enterFilterStage(input: value)
            return .convertedInput(value: value, reading: reading)
        case let .filter(.apply(condition)):
            if !conditions.contains(condition) {
                conditions.append(condition)
            }
        case let .filter(.remove(index, _)):
            if conditions.indices.contains(index) {
                conditions.remove(at: index)
            }
        }
        self.draft = nil
        return .conditionsChanged
    }

    public mutating func cancelDraft() {
        draft = nil
    }

    @discardableResult
    public mutating func removeLastCondition() -> Bool {
        draft = nil
        guard !conditions.isEmpty else { return false }
        conditions.removeLast()
        return true
    }

    public mutating func reset() {
        conditions = []
        draft = nil
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
            conditions.append(.contains(String(component)))
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
        case let .contains(value): matchesContains(value, candidate: candidate)
        case .kanjiOnly: !candidate.isEmpty && candidate.allSatisfy(isKanji)
        case .hiraganaOnly: !candidate.isEmpty && candidate.allSatisfy(isHiragana)
        case .katakanaOnly: !candidate.isEmpty && candidate.allSatisfy(isKatakana)
        case .containsAlphanumeric: candidate.contains { $0.isASCII && $0.isLetter || $0.isNumber }
        case let .kanjiCount(count): candidate.filter(isKanji).count == count
        case let .strokeCount(count): candidate.contains {
            kanjiDatabase.attributes(for: $0)?.strokeCount == count
        }
        case .semantic: true
        }
    }

    private func matchesContains(_ value: String, candidate: String) -> Bool {
        if candidate.localizedCaseInsensitiveContains(value) {
            return true
        }
        guard value.count == 1, let element = value.first else {
            return false
        }
        return candidate.contains { character in
            containsCharacterElement(element, in: character)
        }
    }

    private func containsCharacterElement(
        _ element: Character,
        in character: Character
    ) -> Bool {
        let canonicalElement = KanjiRadicalNormalizer.canonical(element)
        if KanjiRadicalNormalizer.canonical(character) == canonicalElement {
            return true
        }
        guard let attributes = kanjiDatabase.attributes(for: character) else {
            return false
        }
        if let radical = attributes.radical,
           KanjiRadicalNormalizer.canonical(radical) == canonicalElement {
            return true
        }
        return attributes.components.contains {
            KanjiRadicalNormalizer.canonical($0) == canonicalElement
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
