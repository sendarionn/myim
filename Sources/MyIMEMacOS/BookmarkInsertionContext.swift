import AppKit
import InputMethodKit
import MyIMECore

final class BookmarkInsertionContext {
    private weak var clientObject: AnyObject?
    let selectedRange: NSRange
    let bundleIdentifier: String
    let anchorFrame: NSRect

    init?(client: Any, anchorFrame: NSRect) {
        guard let object = client as AnyObject?,
              let textClient = client as? IMKTextInput else { return nil }
        let selectedRange = textClient.selectedRange()
        let markedRange = textClient.markedRange()
        guard selectedRange.location != NSNotFound,
              markedRange.location == NSNotFound || markedRange.length == 0,
              let bundleIdentifier = textClient.bundleIdentifier() else {
            return nil
        }
        clientObject = object
        self.selectedRange = selectedRange
        self.bundleIdentifier = bundleIdentifier
        self.anchorFrame = anchorFrame
    }

    func matches(_ client: Any) -> Bool {
        guard let object = client as AnyObject?,
              object === clientObject,
              let textClient = client as? IMKTextInput,
              textClient.bundleIdentifier() == bundleIdentifier,
              textClient.selectedRange() == selectedRange else {
            return false
        }
        let markedRange = textClient.markedRange()
        return markedRange.location == NSNotFound || markedRange.length == 0
    }
}

enum BookmarkLinkInsertionSupport {
    /// Add a client only after its attributed-string insertion and link
    /// activation have both been verified on the installed input method
    private static let verifiedBundleIdentifiers: Set<String> = []

    static func supports(bundleIdentifier: String) -> Bool {
        verifiedBundleIdentifiers.contains(bundleIdentifier)
    }
}
