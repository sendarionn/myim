import Carbon

enum SecureInputDetector {
    static var isEnabled: Bool {
        IsSecureEventInputEnabled()
    }
}
