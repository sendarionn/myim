import Foundation

public enum CalculatorCandidateGenerator {
    private static let maximumExpressionLength = 128
    private static let maximumMagnitude = 1e15

    public static func candidates(for input: String) -> [String] {
        guard input.hasSuffix("="), input.count <= maximumExpressionLength else {
            return []
        }
        let expression = String(input.dropLast())
        guard !expression.isEmpty,
              var parser = ArithmeticParser(expression),
              let value = parser.parse(),
              value.isFinite,
              abs(value) <= maximumMagnitude else {
            return []
        }
        let normalized = abs(value) < 1e-12 ? 0 : value
        return [format(normalized)]
    }

    private static func format(_ value: Double) -> String {
        if value.rounded() == value {
            return String(format: "%.0f", value)
        }
        return String(format: "%.12g", value)
    }
}

private struct ArithmeticParser {
    private let characters: [Character]
    private var index = 0

    init?(_ expression: String) {
        let compact = expression.filter { !$0.isWhitespace }
        guard !compact.isEmpty,
              compact.allSatisfy({ "0123456789.+-*/()".contains($0) }) else {
            return nil
        }
        characters = Array(compact)
    }

    mutating func parse() -> Double? {
        guard let value = parseExpression(), index == characters.count else {
            return nil
        }
        return value
    }

    private mutating func parseExpression() -> Double? {
        guard var value = parseTerm() else { return nil }
        while let operation = current, operation == "+" || operation == "-" {
            index += 1
            guard let right = parseTerm() else { return nil }
            value = operation == "+" ? value + right : value - right
        }
        return value
    }

    private mutating func parseTerm() -> Double? {
        guard var value = parseUnary() else { return nil }
        while let operation = current, operation == "*" || operation == "/" {
            index += 1
            guard let right = parseUnary() else { return nil }
            if operation == "/", right == 0 { return nil }
            value = operation == "*" ? value * right : value / right
        }
        return value
    }

    private mutating func parseUnary() -> Double? {
        if current == "+" {
            index += 1
            return parseUnary()
        }
        if current == "-" {
            index += 1
            return parseUnary().map { -$0 }
        }
        return parsePrimary()
    }

    private mutating func parsePrimary() -> Double? {
        if current == "(" {
            index += 1
            guard let value = parseExpression(), current == ")" else {
                return nil
            }
            index += 1
            return value
        }
        return parseNumber()
    }

    private mutating func parseNumber() -> Double? {
        let start = index
        var decimalPointCount = 0
        while let character = current,
              character.isNumber || character == "." {
            if character == "." { decimalPointCount += 1 }
            guard decimalPointCount <= 1 else { return nil }
            index += 1
        }
        guard index > start else { return nil }
        return Double(String(characters[start..<index]))
    }

    private var current: Character? {
        index < characters.count ? characters[index] : nil
    }
}
