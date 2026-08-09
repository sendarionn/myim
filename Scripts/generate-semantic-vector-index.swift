#!/usr/bin/env swift

import Foundation
import NaturalLanguage

struct SemanticEntry: Decodable {
    let glosses: [String]
    let explanations: [String]
}

let stopWords: Set<String> = [
    "a", "an", "and", "as", "at", "be", "by", "for", "from", "in",
    "is", "it", "of", "on", "or", "that", "the", "this", "to", "used",
    "who", "with"
]

func averageVector(
    of text: String,
    embedding: NLEmbedding
) -> [Double]? {
    let tokenizer = NLTokenizer(unit: .word)
    tokenizer.setLanguage(.english)
    tokenizer.string = text
    var sum = Array(repeating: 0.0, count: embedding.dimension)
    var count = 0
    tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
        let token = text[range].lowercased()
        guard !stopWords.contains(token),
              let vector = embedding.vector(for: token) else {
            return true
        }
        for index in vector.indices {
            sum[index] += vector[index]
        }
        count += 1
        return true
    }
    guard count > 0 else { return nil }
    return sum.map { $0 / Double(count) }
}

func appendLittleEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
}

guard CommandLine.arguments.count == 3 else {
    fputs("使用法: generate-semantic-vector-index.swift 入力JSONL 出力索引\n", stderr)
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let embedding = NLEmbedding.wordEmbedding(for: .english) else {
    fputs("英語の単語埋め込みを利用できません\n", stderr)
    exit(1)
}

let source = try String(contentsOf: inputURL, encoding: .utf8)
let decoder = JSONDecoder()
var sourceVectors: [(entryIndex: UInt32, values: [Double])] = []
for (entryIndex, line) in source.split(separator: "\n").enumerated() {
    let entry = try decoder.decode(SemanticEntry.self, from: Data(line.utf8))
    let text = (entry.glosses + entry.explanations).joined(separator: ". ")
    guard let vector = averageVector(of: text, embedding: embedding) else {
        continue
    }
    sourceVectors.append((UInt32(entryIndex), vector))
}
var centroid = Array(repeating: 0.0, count: embedding.dimension)
for vector in sourceVectors {
    for index in vector.values.indices {
        centroid[index] += vector.values[index]
    }
}
for index in centroid.indices {
    centroid[index] /= Double(sourceVectors.count)
}

var records = Data()
for vector in sourceVectors {
    let centered = zip(vector.values, centroid).map(-)
    let magnitude = sqrt(centered.reduce(0.0) { $0 + $1 * $1 })
    guard magnitude > 0 else { continue }
    appendLittleEndian(vector.entryIndex, to: &records)
    for value in centered {
        appendLittleEndian(Float16(value / magnitude).bitPattern, to: &records)
    }
}

var output = Data("MYIMSV01".utf8)
appendLittleEndian(UInt32(2), to: &output)
appendLittleEndian(UInt32(embedding.dimension), to: &output)
appendLittleEndian(UInt32(sourceVectors.count), to: &output)
for value in centroid {
    appendLittleEndian(Float(value).bitPattern, to: &output)
}
output.append(records)
try output.write(to: outputURL, options: .atomic)
print("ベクトル次元: \(embedding.dimension)")
print("索引項目数: \(sourceVectors.count)")
print("保存先: \(outputURL.path)")
