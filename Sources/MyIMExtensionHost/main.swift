import Foundation
import JavaScriptCore
import MyIMECore

private let decoder = JSONDecoder()
private let encoder = JSONEncoder()

while let line = readLine() {
    guard let data = line.data(using: .utf8),
          let request = try? decoder.decode(
            JavaScriptExtensionRequest.self,
            from: data
          ) else {
        continue
    }

    var candidates: [String] = []
    var errors: [String] = []
    var statuses: [JavaScriptExtensionStatus] = []
    var seen = Set<String>()
    let disabledFileNames = Set(request.disabledFileNames)

    for directory in request.extensionDirectories {
        let directoryURL = URL(fileURLWithPath: directory, isDirectory: true)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        for fileURL in files
            .filter({ $0.pathExtension.lowercased() == "js" })
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let fileName = fileURL.lastPathComponent
            if disabledFileNames.contains(fileName) {
                statuses.append(.init(fileName: fileName, state: .disabled))
                continue
            }
            guard let source = try? String(contentsOf: fileURL, encoding: .utf8)
            else {
                let message = "読み込めません"
                errors.append("\(fileName): \(message)")
                statuses.append(.init(fileName: fileName, state: .error, message: message))
                continue
            }
            if let prefix = metadataValue("myim-prefix", in: source),
               !request.input.hasPrefix(prefix) {
                statuses.append(.init(fileName: fileName, state: .ready))
                continue
            }
            guard let context = JSContext() else {
                let message = "JSContextを作成できません"
                errors.append("\(fileName): \(message)")
                statuses.append(.init(fileName: fileName, state: .error, message: message))
                continue
            }
            var exceptionMessage: String?
            context.exceptionHandler = { _, exception in
                exceptionMessage = exception?.toString()
            }
            context.evaluateScript(source, withSourceURL: fileURL)
            guard exceptionMessage == nil,
                  let function = context.objectForKeyedSubscript("candidates"),
                  !function.isUndefined else {
                let message = exceptionMessage ?? "candidates関数がありません"
                errors.append("\(fileName): \(message)")
                statuses.append(.init(fileName: fileName, state: .error, message: message))
                continue
            }
            let input: [String: Any] = [
                "input": request.input,
                "timestamp": request.timestamp,
                "timeZone": request.timeZone,
                "settings": request.settings
            ]
            guard let value = function.call(withArguments: [input]),
                  exceptionMessage == nil else {
                let message = exceptionMessage ?? "実行できません"
                errors.append("\(fileName): \(message)")
                statuses.append(.init(fileName: fileName, state: .error, message: message))
                continue
            }
            for candidate in candidateStrings(from: value) {
                let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, trimmed.count <= 256,
                   seen.insert(trimmed).inserted, candidates.count < 32 {
                    candidates.append(trimmed)
                }
            }
            statuses.append(.init(fileName: fileName, state: .ready))
        }
    }

    let response = JavaScriptExtensionResponse(
        id: request.id,
        candidates: candidates,
        errors: errors,
        statuses: statuses
    )
    if let output = try? encoder.encode(response) {
        FileHandle.standardOutput.write(output)
        FileHandle.standardOutput.write(Data([0x0A]))
    }
}

private func metadataValue(_ name: String, in source: String) -> String? {
    let marker = "// @\(name) "
    return source.split(separator: "\n", omittingEmptySubsequences: false)
        .prefix(20)
        .compactMap { line -> String? in
            let text = String(line)
            guard text.hasPrefix(marker) else { return nil }
            let value = String(text.dropFirst(marker.count))
                .trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }
        .first
}

private func candidateStrings(from value: JSValue) -> [String] {
    guard let array = value.toArray() else { return [] }
    return array.compactMap { element in
        if let string = element as? String {
            return string
        }
        if let object = element as? [String: Any] {
            return object["value"] as? String
        }
        return nil
    }
}
