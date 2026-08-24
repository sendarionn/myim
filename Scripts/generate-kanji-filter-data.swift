#!/usr/bin/env swift

import Foundation

guard CommandLine.arguments.count == 4 else {
    fputs("usage: generate-kanji-filter-data.swift UNIHAN_DIR EXISTING_DATA OUTPUT\n", stderr)
    exit(2)
}

let unihanDirectory = URL(fileURLWithPath: CommandLine.arguments[1])
let existingURL = URL(fileURLWithPath: CommandLine.arguments[2])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[3])
var radicals: [UInt32: Character] = [:]
var strokes: [UInt32: Int] = [:]
var components: [UInt32: String] = [:]

if let existing = try? String(contentsOf: existingURL, encoding: .utf8) {
    for line in existing.split(whereSeparator: \Character.isNewline) {
        let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
        guard fields.count >= 4,
              let scalar = fields[0].unicodeScalars.first?.value else { continue }
        components[scalar] = String(fields[3])
    }
}

let files = try FileManager.default.contentsOfDirectory(
    at: unihanDirectory,
    includingPropertiesForKeys: nil
).filter { $0.lastPathComponent.hasPrefix("Unihan_") }

for file in files {
    let text = try String(contentsOf: file, encoding: .utf8)
    for line in text.split(whereSeparator: \Character.isNewline) where !line.hasPrefix("#") {
        let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
        guard fields.count == 3,
              fields[0].hasPrefix("U+"),
              let scalar = UInt32(fields[0].dropFirst(2), radix: 16) else { continue }
        switch fields[1] {
        case "kRSUnicode":
            guard let radicalNumber = Int(
                fields[2].split(separator: " ").first?
                    .split(separator: ".").first ?? ""
            ), (1...214).contains(radicalNumber),
               let kangxi = UnicodeScalar(0x2f00 + radicalNumber - 1) else { continue }
            let normalized = String(kangxi).precomposedStringWithCompatibilityMapping
            radicals[scalar] = normalized.first
        case "kTotalStrokes":
            if let value = fields[2].split(separator: " ").first,
               let count = Int(value) {
                strokes[scalar] = count
            }
        default:
            break
        }
    }
}

let scalars = Set(radicals.keys).union(strokes.keys).union(components.keys).sorted()
let output = scalars.compactMap { value -> String? in
    guard let scalar = UnicodeScalar(value) else { return nil }
    return [
        String(scalar),
        radicals[value].map(String.init) ?? "",
        strokes[value].map(String.init) ?? "",
        components[value] ?? ""
    ].joined(separator: "\t")
}.joined(separator: "\n") + "\n"

try output.write(to: outputURL, atomically: true, encoding: .utf8)
