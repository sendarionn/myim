import Foundation

public struct CandidateFilterIDSStore: Sendable {
    public static let guide = """
    myim 候補フィルター用IDS構成要素データ

    対応拡張子: .txt .tsv .ids
    対応形式: U+XXXX<Tab>対象文字<Tab>IDS記述
    例: U+4F11<Tab>休<Tab>⿰亻木

    ファイルはアプリへコピーされず、このフォルダから直接読み込まれます
    追加や変更は次にOption+Fで候補フィルターを開始したときに反映されます
    データの取得と利用では配布元のライセンスに従ってください
    """

    private static let supportedExtensions: Set<String> = ["txt", "tsv", "ids"]

    public let directoryURL: URL

    public init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    public static func applicationSupport() -> Self? {
        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first.map {
            Self(directoryURL: $0
                .appendingPathComponent("myim", isDirectory: true)
                .appendingPathComponent("CandidateFilter", isDirectory: true)
                .appendingPathComponent("IDS", isDirectory: true))
        }
    }

    public func signature() -> [String] {
        supportedFiles(including: [
            .contentModificationDateKey,
            .fileSizeKey
        ]).map { file in
            let values = try? file.resourceValues(forKeys: [
                .contentModificationDateKey,
                .fileSizeKey
            ])
            return [
                file.lastPathComponent,
                String(values?.fileSize ?? 0),
                String(values?.contentModificationDate?.timeIntervalSince1970 ?? 0)
            ].joined(separator: ":")
        }
    }

    public func supplementalTexts() -> [String] {
        supportedFiles(including: nil).compactMap {
            try? String(contentsOf: $0, encoding: .utf8)
        }
    }

    public func prepareDirectory() throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let guideURL = directoryURL.appendingPathComponent("README.txt")
        if !FileManager.default.fileExists(atPath: guideURL.path) {
            try Self.guide.write(to: guideURL, atomically: true, encoding: .utf8)
        }
    }

    public func saveCJKVIIDS(_ data: Data, downloadedAt date: Date) throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        try data.write(
            to: directoryURL.appendingPathComponent("cjkvi-ids.txt"),
            options: .atomic
        )
        let sourceInformation = """
        Source: https://github.com/cjkvi/cjkvi-ids/blob/master/ids.txt
        Downloaded: \(ISO8601DateFormatter().string(from: date))
        License: CHISE-derived data under the upstream terms
        """
        try sourceInformation.write(
            to: directoryURL.appendingPathComponent("cjkvi-ids-source.md"),
            atomically: true,
            encoding: .utf8
        )
    }

    private func supportedFiles(including keys: [URLResourceKey]?) -> [URL] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return files
            .filter {
                Self.supportedExtensions.contains($0.pathExtension.lowercased())
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
