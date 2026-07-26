import Foundation
import MyIMECore

private let dictionarySource = CosenseDictionarySource(
    project: "sendarionn-public",
    pageTitle: "dictionary"
)

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    let cache = try DictionaryCache.applicationSupport()

    if arguments.first == "sync" {
        let dictionaryText = try await CosenseDictionaryClient().fetch(
            from: dictionarySource
        )
        let entries = try DictionaryParser().parse(dictionaryText)

        guard !entries.isEmpty else {
            throw CosenseDictionaryError.emptyDictionary
        }

        let syncedAt = Date()
        try cache.save(
            dictionaryText: dictionaryText,
            metadata: DictionaryCacheMetadata(
                syncedAt: syncedAt,
                entryCount: entries.count
            )
        )

        print("同期しました")
        print("登録読み数: \(entries.count)")
        print("保存先: \(cache.dictionaryURL.path)")
        exit(EXIT_SUCCESS)
    }

    let dictionaryURL: URL
    let dictionarySourceDescription: String

    if let dictionaryPath = arguments.first {
        dictionaryURL = URL(fileURLWithPath: dictionaryPath)
        dictionarySourceDescription = dictionaryURL.path
    } else if cache.containsDictionary() {
        dictionaryURL = cache.dictionaryURL
        dictionarySourceDescription = "Cosenseキャッシュ"
    } else {
        guard let bundledURL = Bundle.module.url(
            forResource: "dictionary",
            withExtension: "txt"
        ) else {
            throw CLIError.bundledDictionaryNotFound
        }
        dictionaryURL = bundledURL
        dictionarySourceDescription = "同梱テスト辞書"
    }

    let dictionaryText = try String(contentsOf: dictionaryURL, encoding: .utf8)
    let entries = try DictionaryParser().parse(dictionaryText)
    let engine = ConversionEngine(entries: entries)

    print("my-ime")
    print("辞書: \(dictionarySourceDescription)")
    if arguments.isEmpty, let metadata = try? cache.loadMetadata() {
        print("登録読み数: \(metadata.entryCount)")
        print("最終同期: \(metadata.syncedAt.formatted())")
    }
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
            project: dictionarySource.project,
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
