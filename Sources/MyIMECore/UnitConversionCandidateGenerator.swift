import Foundation

public enum UnitConversionCandidateGenerator {
    private struct Unit {
        let symbol: String
        let aliases: Set<String>
        let factor: Decimal
        let normalizesInput: Bool
    }

    private static let linearFamilies: [[Unit]] = [
        [
            unit("mm", "0.001"), unit("cm", "0.01"),
            unit("m", "1"), unit("km", "1000")
        ],
        [
            unit("mg", "0.001"), unit("g", "1"),
            unit("kg", "1000"), unit("t", "1000000")
        ],
        [
            unit("mL", "0.001", aliases: ["ml", "cc"]),
            unit("cL", "0.01", aliases: ["cl"]),
            unit("dL", "0.1", aliases: ["dl"]),
            unit("L", "1", aliases: ["l"])
        ],
        [
            unit("mm2", "0.000001"), unit("cm2", "0.0001"),
            unit("m2", "1"), unit("ha", "10000"),
            unit("km2", "1000000")
        ],
        [
            unit("ms", "0.001"), unit("s", "1"),
            unit("min", "60"), unit("h", "3600"),
            unit("d", "86400")
        ],
        [
            unit(
                "ミリ秒",
                "0.001",
                aliases: ["miribyou", "ミリ秒"],
                normalizesInput: true
            ),
            unit(
                "秒",
                "1",
                aliases: ["byou", "秒"],
                normalizesInput: true
            ),
            unit(
                "分",
                "60",
                aliases: ["fun", "hun", "分"],
                normalizesInput: true
            ),
            unit(
                "時間",
                "3600",
                aliases: ["jikan", "時間"],
                normalizesInput: true
            ),
            unit(
                "日",
                "86400",
                aliases: ["nichi", "日"],
                normalizesInput: true
            )
        ],
        [
            unit("m/s", "1"),
            unit("km/h", "0.277777777777777778")
        ]
    ]

    public static func candidates(for input: String) -> [String] {
        if let temperature = temperatureCandidates(for: input) {
            return temperature
        }
        let normalized = input.lowercased()
        for family in linearFamilies {
            let orderedUnits = family.sorted {
                ($0.aliases.map(\.count).max() ?? 0)
                    > ($1.aliases.map(\.count).max() ?? 0)
            }
            guard let source = orderedUnits.first(where: { unit in
                unit.aliases.contains { normalized.hasSuffix($0) }
            }) else {
                continue
            }
            let matchedAlias = source.aliases
                .filter { normalized.hasSuffix($0) }
                .max(by: { $0.count < $1.count }) ?? source.symbol
            guard let value = parsedNumber(
                String(input.dropLast(matchedAlias.count))
            ) else {
                continue
            }
            let baseValue = value * source.factor
            var conversions = family.compactMap { target -> (Unit, Decimal)? in
                guard target.symbol != source.symbol else { return nil }
                let converted = baseValue / target.factor
                let magnitude = abs(
                    NSDecimalNumber(decimal: converted).doubleValue
                )
                let minimumMagnitude = source.normalizesInput ? 1.0 : 0.01
                guard magnitude == 0 || magnitude >= minimumMagnitude else {
                    return nil
                }
                return (target, converted)
            }
            if source.normalizesInput,
               matchedAlias.lowercased() != source.symbol.lowercased() {
                conversions.append((source, value))
            }
            conversions.sort {
                abs(NSDecimalNumber(decimal: $0.1).doubleValue)
                    < abs(NSDecimalNumber(decimal: $1.1).doubleValue)
            }
            let convertedCandidates = conversions.flatMap { target, converted in
                formattedCandidates(converted, symbol: target.symbol)
            }
            let sourceValue = String(input.dropLast(matchedAlias.count))
            let japaneseUnitCandidates = JapaneseNumericUnitCandidateGenerator
                .candidates(for: sourceValue)
                .map { candidate in
                    (candidate == "1千" ? "千" : candidate) + source.symbol
                }
            return convertedCandidates + japaneseUnitCandidates
        }
        return []
    }

    private static func temperatureCandidates(for input: String) -> [String]? {
        let normalized = input.lowercased()
        let symbols = ["°c", "°f", "c", "f", "k"]
        guard let source = symbols.first(where: { normalized.hasSuffix($0) }),
              let value = parsedNumber(
                  String(input.dropLast(source.count))
              ) else {
            return nil
        }
        let celsius: Decimal
        switch source {
        case "f", "°f": celsius = (value - 32) * 5 / 9
        case "k": celsius = value - Decimal(string: "273.15")!
        default: celsius = value
        }
        switch source {
        case "c", "°c":
            return formattedCandidates(celsius * 9 / 5 + 32, symbol: "°F")
                + formattedCandidates(
                    celsius + Decimal(string: "273.15")!,
                    symbol: "K"
                )
        case "f", "°f":
            return formattedCandidates(celsius, symbol: "°C")
                + formattedCandidates(
                    celsius + Decimal(string: "273.15")!,
                    symbol: "K"
                )
        default:
            return formattedCandidates(celsius, symbol: "°C")
                + formattedCandidates(celsius * 9 / 5 + 32, symbol: "°F")
        }
    }

    private static func formattedCandidates(
        _ value: Decimal,
        symbol: String
    ) -> [String] {
        let number = format(value)
        return ([number] + NumberGroupingCandidateGenerator.candidates(for: number))
            .map { $0 + symbol }
    }

    private static func parsedNumber(_ text: String) -> Decimal? {
        guard !text.isEmpty,
              text.range(
                  of: #"^[+-]?(?:\d+(?:\.\d*)?|\.\d+)$"#,
                  options: .regularExpression
              ) != nil else {
            return nil
        }
        return Decimal(
            string: text,
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    private static func unit(
        _ symbol: String,
        _ factor: String,
        aliases: Set<String>? = nil,
        normalizesInput: Bool = false
    ) -> Unit {
        Unit(
            symbol: symbol,
            aliases: aliases ?? [symbol.lowercased()],
            factor: Decimal(string: factor)!,
            normalizesInput: normalizesInput
        )
    }

    private static func format(_ value: Decimal) -> String {
        var value = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 12, .plain)
        return NSDecimalNumber(decimal: rounded).stringValue
    }
}
