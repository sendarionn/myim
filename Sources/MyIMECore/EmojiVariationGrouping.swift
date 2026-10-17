public struct EmojiVariationGrouping: Equatable, Sendable {
    public let mainCodes: [String]
    public let memberCodesByBaseCode: [String: [String]]

    public init(codes: [String]) {
        let normalizedToOriginal = codes.reduce(into: [String: String]()) {
            result, code in
            result[Self.normalized(code), default: code] = code
        }
        let knownCodes = Set(normalizedToOriginal.keys)
        var orderedBaseCodes: [String] = []
        var members: [String: [String]] = [:]

        for code in codes {
            let normalizedCode = Self.normalized(code)
            let baseCode = Self.baseCode(
                for: normalizedCode,
                knownCodes: knownCodes
            )
            guard let originalBaseCode = normalizedToOriginal[baseCode] else {
                continue
            }
            if members[originalBaseCode] == nil {
                orderedBaseCodes.append(originalBaseCode)
            }
            members[originalBaseCode, default: []].append(code)
        }

        mainCodes = orderedBaseCodes
        memberCodesByBaseCode = Dictionary(uniqueKeysWithValues: members.map {
            baseCode, codes in
            (baseCode, [baseCode] + codes.filter { $0 != baseCode })
        })
    }

    public func memberCodes(forBaseCode code: String) -> [String] {
        memberCodesByBaseCode[code] ?? [code]
    }

    private static func baseCode(
        for code: String,
        knownCodes: Set<String>
    ) -> String {
        let withoutSkinTone = code.split(separator: "-")
            .map(String.init)
            .filter { !isSkinToneModifier($0) }
        var components = withoutSkinTone
        if withoutSkinTone.count >= 2,
           withoutSkinTone[withoutSkinTone.count - 2] == "200d",
           isGenderMarker(withoutSkinTone.last!),
           knownCodes.contains(
               withoutSkinTone.dropLast(2).joined(separator: "-")
           ) {
            components = Array(withoutSkinTone.dropLast(2))
        }
        let genderNeutralized = components.map { component in
            component == "1f468" || component == "1f469"
                ? "1f9d1"
                : component
        }.joined(separator: "-")
        if components.count > 1, knownCodes.contains(genderNeutralized) {
            return genderNeutralized
        }
        let skinToneBase = components.joined(separator: "-")
        if knownCodes.contains(skinToneBase) {
            return skinToneBase
        }
        return code
    }

    private static func normalized(_ code: String) -> String {
        code.lowercased()
    }

    private static func isSkinToneModifier(_ component: String) -> Bool {
        guard let value = UInt32(component, radix: 16) else { return false }
        return (0x1F3FB...0x1F3FF).contains(value)
    }

    private static func isGenderMarker(_ component: String) -> Bool {
        component == "2640" || component == "2642"
    }
}
