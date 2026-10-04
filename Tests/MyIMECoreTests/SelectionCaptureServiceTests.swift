import Foundation
import Testing
@testable import MyIMECore

@Suite
@MainActor
struct SelectionCaptureServiceTests {
    @Test
    func capturesTextAndRestoresEveryPasteboardRepresentation() async {
        let original = SelectionPasteboardSnapshot(items: [
            [
                "public.utf8-plain-text": Data("original".utf8),
                "public.rtf": Data([0x7B, 0x5C, 0x72, 0x74, 0x66])
            ],
            ["public.file-url": Data("file:///tmp/sample".utf8)]
        ])
        let pasteboard = MockSelectionPasteboard(snapshot: original)
        let sender = MockSelectionCopySender {
            pasteboard.publishCopiedText("selected")
            return true
        }

        let result = await SelectionCaptureService().capture(
            pasteboard: pasteboard,
            copySender: sender
        )

        #expect(result == .success("selected"))
        #expect(pasteboard.restoredSnapshot == original)
    }

    @Test(arguments: [
        "https://github.com/sendarionn/myim",
        "複数行\n  Spaceを保持\tTab",
        "絵文字🙂と異体字葛󠄀"
    ])
    func preservesSelectedTextExactly(_ text: String) async {
        let pasteboard = MockSelectionPasteboard()
        let sender = MockSelectionCopySender {
            pasteboard.publishCopiedText(text)
            return true
        }

        let result = await SelectionCaptureService().capture(
            pasteboard: pasteboard,
            copySender: sender
        )

        #expect(result == .success(text))
    }

    @Test
    func acceptsCopyWhenTextMatchesThePreviousClipboard() async {
        let pasteboard = MockSelectionPasteboard(
            snapshot: SelectionPasteboardSnapshot(items: [[
                "public.utf8-plain-text": Data("same".utf8)
            ]])
        )
        let sender = MockSelectionCopySender {
            pasteboard.publishCopiedText("same")
            return true
        }

        let result = await SelectionCaptureService().capture(
            pasteboard: pasteboard,
            copySender: sender
        )

        #expect(result == .success("same"))
    }

    @Test
    func reportsTimeoutAndRestoresClipboard() async {
        let original = SelectionPasteboardSnapshot(items: [[
            "public.utf8-plain-text": Data("original".utf8)
        ]])
        let pasteboard = MockSelectionPasteboard(snapshot: original)

        let result = await SelectionCaptureService(
            timeoutNanoseconds: 1_000_000,
            pollingNanoseconds: 100_000
        ).capture(
            pasteboard: pasteboard,
            copySender: MockSelectionCopySender { true }
        )

        #expect(result == .failure(.pasteboardNotUpdated))
        #expect(pasteboard.restoredSnapshot == original)
    }

    @Test
    func distinguishesCopyFailureFromMissingText() async {
        let unavailablePasteboard = MockSelectionPasteboard()
        let unavailable = await SelectionCaptureService().capture(
            pasteboard: unavailablePasteboard,
            copySender: MockSelectionCopySender { false }
        )
        #expect(unavailable == .failure(.copyUnavailable))

        let noTextPasteboard = MockSelectionPasteboard()
        let noText = await SelectionCaptureService().capture(
            pasteboard: noTextPasteboard,
            copySender: MockSelectionCopySender {
                noTextPasteboard.publishCopiedText(nil)
                return true
            }
        )
        #expect(noText == .failure(.copiedDataHasNoText))
    }
}

@MainActor
private final class MockSelectionPasteboard: SelectionPasteboardClient {
    private(set) var changeCount = 0
    private let originalSnapshot: SelectionPasteboardSnapshot
    private var copiedText: String?
    private(set) var restoredSnapshot: SelectionPasteboardSnapshot?

    init(snapshot: SelectionPasteboardSnapshot = .init(items: [])) {
        originalSnapshot = snapshot
    }

    func snapshot() throws -> SelectionPasteboardSnapshot {
        originalSnapshot
    }

    func prepareForCopy() throws -> Int {
        changeCount += 1
        copiedText = nil
        return changeCount
    }

    func copiedString() -> String? {
        copiedText
    }

    func restore(_ snapshot: SelectionPasteboardSnapshot) throws {
        restoredSnapshot = snapshot
        changeCount += 1
    }

    func publishCopiedText(_ text: String?) {
        copiedText = text
        changeCount += 1
    }
}

@MainActor
private struct MockSelectionCopySender: SelectionCopySender {
    let action: () -> Bool

    init(_ action: @escaping () -> Bool) {
        self.action = action
    }

    func sendCopy() -> Bool {
        action()
    }
}
