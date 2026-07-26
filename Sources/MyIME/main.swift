import Foundation
import MyIMECore

private let projectName = "sendarionn"

do {
    let dictionaryURL: URL
    if CommandLine.arguments.count >= 2 {
        dictionaryURL = URL(fileURLWithPath: CommandLine.arguments[1])
    } else {
        guard let bundledURL = Bundle.module.url(
            forResource: "dictionary",
            withExtension: "txt"
        ) else {
            throw CLIError.bundledDictionaryNotFound
        }
        dictionaryURL = bundledURL
    }

    let dictionaryText = try String(contentsOf: dictionaryURL, encoding: .utf8)
    let entries = try DictionaryParser().parse(dictionaryText)
    let engine = ConversionEngine(entries: entries)

    print("my-ime")
    print("読みを入力してください")
    print("終了するには空のままEnterを押してください")

    while true {
        print("> ", terminator: "")
        guard let reading = readLine(), !reading.isEmpty else {
            break
        }

        let candidates = engine.candidates(for: reading)
        guard !candidates.isEmpty else {
            print("候補がありません: \(reading)")
            continue
        }

        for (index, candidate) in candidates.enumerated() {
            print("\(index + 1)  \(candidate)")
        }

        print("候補番号> ", terminator: "")
        guard
            let selection = readLine(),
            let selectedNumber = Int(selection),
            candidates.indices.contains(selectedNumber - 1)
        else {
            print("候補番号が正しくありません")
            continue
        }

        let selectedCandidate = candidates[selectedNumber - 1]
        print("確定: \(selectedCandidate)")

        if let url = CosensePageURL.make(
            project: projectName,
            pageTitle: selectedCandidate
        ) {
            print("Cosense: \(url.absoluteString)")
        }
    }
} catch {
    FileHandle.standardError.write(
        Data("エラー: \(error.localizedDescription)\n".utf8)
    )
    exit(EXIT_FAILURE)
}

private enum CLIError: LocalizedError {
    case bundledDictionaryNotFound

    var errorDescription: String? {
        switch self {
        case .bundledDictionaryNotFound:
            return "同梱された辞書が見つかりません"
        }
    }
}
