import Carbon
import Foundation

enum InputSourceRegistrationManager {
    static let myIMIdentifier =
        "io.github.sendarionn.inputmethod.myime.Japanese"
    static let fallbackIdentifier = "com.apple.keylayout.ABC"

    static var isRegistered: Bool {
        source(identifier: myIMIdentifier, includeAllInstalled: true) != nil
    }

    static var isSelected: Bool {
        selectedSourceIdentifier() == myIMIdentifier
    }

    static var isEnabled: Bool {
        guard let source = source(
            identifier: myIMIdentifier,
            includeAllInstalled: true
        ) else { return false }
        return booleanProperty(source, key: kTISPropertyInputSourceIsEnabled)
    }

    static var isFallbackSelected: Bool {
        selectedSourceIdentifier() == fallbackIdentifier
    }

    static func register(bundleURL: URL) throws {
        let status = TISRegisterInputSource(bundleURL as CFURL)
        try validate(status, operation: "入力ソースの登録")
        guard isRegistered else {
            throw RegistrationError.sourceNotFoundAfterRegistration
        }
    }

    static func enableMyIM() throws {
        guard let source = source(
            identifier: myIMIdentifier,
            includeAllInstalled: true
        ) else {
            throw RegistrationError.sourceNotFound
        }
        try validate(TISEnableInputSource(source), operation: "入力ソースの有効化")
    }

    static func selectMyIM() throws {
        try select(identifier: myIMIdentifier, includeAllInstalled: true)
    }

    static func selectFallback() throws {
        try select(identifier: fallbackIdentifier, includeAllInstalled: false)
    }

    private static func select(
        identifier: String,
        includeAllInstalled: Bool
    ) throws {
        guard let source = source(
            identifier: identifier,
            includeAllInstalled: includeAllInstalled
        ) else {
            throw RegistrationError.sourceNotFound
        }
        try validate(TISSelectInputSource(source), operation: "入力ソースの選択")
    }

    private static func source(
        identifier: String,
        includeAllInstalled: Bool
    ) -> TISInputSource? {
        let sources = TISCreateInputSourceList(nil, includeAllInstalled)
            .takeRetainedValue() as! [TISInputSource]
        return sources.first {
            sourceIdentifier($0) == identifier
        }
    }

    private static func selectedSourceIdentifier() -> String? {
        sourceIdentifier(TISCopyCurrentKeyboardInputSource().takeRetainedValue())
    }

    private static func sourceIdentifier(_ source: TISInputSource) -> String? {
        guard let pointer = TISGetInputSourceProperty(
            source,
            kTISPropertyInputSourceID
        ) else { return nil }
        return Unmanaged<CFString>
            .fromOpaque(pointer)
            .takeUnretainedValue() as String
    }

    private static func booleanProperty(
        _ source: TISInputSource,
        key: CFString
    ) -> Bool {
        guard let pointer = TISGetInputSourceProperty(source, key) else {
            return false
        }
        return Unmanaged<CFBoolean>
            .fromOpaque(pointer)
            .takeUnretainedValue() == kCFBooleanTrue
    }

    private static func validate(_ status: OSStatus, operation: String) throws {
        guard status == noErr else {
            throw RegistrationError.operationFailed(operation, status)
        }
    }
}

private enum RegistrationError: LocalizedError {
    case sourceNotFound
    case sourceNotFoundAfterRegistration
    case operationFailed(String, OSStatus)

    var errorDescription: String? {
        switch self {
        case .sourceNotFound:
            return "入力ソースが見つかりません"
        case .sourceNotFoundAfterRegistration:
            return "登録後の入力ソースが見つかりません"
        case let .operationFailed(operation, status):
            return "\(operation)に失敗しました: \(status)"
        }
    }
}
