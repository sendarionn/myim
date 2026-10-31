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

    var candidates: [JavaScriptExtensionCandidate] = []
    var errors: [String] = []
    var statuses: [JavaScriptExtensionStatus] = []
    var seen = Set<JavaScriptExtensionCandidate>()
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
            let prefixes = JavaScriptExtensionMetadata.values(
                "myim-prefix",
                in: source
            )
            if !JavaScriptExtensionMetadata.matches(
                input: request.input,
                prefixes: prefixes
            ) {
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
            let functionName = request.functionName ?? "candidates"
            guard exceptionMessage == nil,
                  let function = context.objectForKeyedSubscript(functionName),
                  !function.isUndefined else {
                if request.functionName != nil, exceptionMessage == nil {
                    statuses.append(.init(fileName: fileName, state: .ready))
                    continue
                }
                let message = exceptionMessage ?? "candidates関数がありません"
                errors.append("\(fileName): \(message)")
                statuses.append(.init(fileName: fileName, state: .error, message: message))
                continue
            }
            let input: [String: Any] = [
                "input": request.input,
                "timestamp": request.timestamp,
                "timeZone": request.timeZone,
                "settings": request.settings,
                "parameters": request.parameters ?? [:]
            ]
            guard let value = function.call(withArguments: [input]),
                  exceptionMessage == nil else {
                let message = exceptionMessage ?? "実行できません"
                errors.append("\(fileName): \(message)")
                statuses.append(.init(fileName: fileName, state: .error, message: message))
                continue
            }
            for candidate in extensionCandidates(from: value) {
                let trimmed = candidate.value.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                let normalized = JavaScriptExtensionCandidate(
                    value: trimmed,
                    kind: candidate.kind,
                    preferenceID: candidate.preferenceID
                )
                if !trimmed.isEmpty, trimmed.count <= 256,
                   seen.insert(normalized).inserted, candidates.count < 32 {
                    candidates.append(normalized)
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

private func extensionCandidates(
    from value: JSValue
) -> [JavaScriptExtensionCandidate] {
    guard let array = value.toArray() else { return [] }
    return array.compactMap { element in
        if let string = element as? String {
            return JavaScriptExtensionCandidate(value: string)
        }
        if let object = element as? [String: Any] {
            guard let value = object["value"] as? String else { return nil }
            let kind = (object["kind"] as? String)
                .flatMap(JavaScriptExtensionCandidateKind.init(rawValue:))
                ?? .staticValue
            return JavaScriptExtensionCandidate(
                value: value,
                kind: kind,
                preferenceID: object["preferenceID"] as? String
            )
        }
        return nil
    }
}
