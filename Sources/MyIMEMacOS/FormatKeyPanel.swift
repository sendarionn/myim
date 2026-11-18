@preconcurrency import AppKit
import MyIMECore

/// An almost invisible panel that takes the keys while formats are chosen
/// in the candidate panel, which does not take keys itself; Return stops the
/// modal session with `.OK` and Esc with `.cancel`
final class FormatKeyPanel: NSPanel {
    var candidateCount = 0
    var selectedIndex: Int?
    var selectionChanged: ((Int?) -> Void)?
    var directionalSelection: ((Int?, CandidateNavigationDirection) -> Int?)?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        animationBehavior = .none
        level = .popUpMenu
        alphaValue = 0.01
        isOpaque = false
        backgroundColor = .clear
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = false
        collectionBehavior = [
            .moveToActiveSpace, .transient, .fullScreenAuxiliary
        ]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 48:
            guard candidateCount > 0 else { return }
            let direction = event.modifierFlags.contains(.shift) ? -1 : 1
            moveSelection(by: direction)
        case 123:
            moveSelection(.left)
        case 124:
            moveSelection(.right)
        case 125:
            moveSelection(.down)
        case 126:
            moveSelection(.up)
        case 36, 76:
            guard selectedIndex != nil else { return }
            NSApp.stopModal(withCode: .OK)
        case 53:
            NSApp.stopModal(withCode: .cancel)
        default:
            break
        }
    }

    private func moveSelection(by offset: Int) {
        guard candidateCount > 0 else { return }
        let current = selectedIndex ?? (offset > 0 ? -1 : 0)
        selectedIndex = (current + offset + candidateCount) % candidateCount
        selectionChanged?(selectedIndex)
    }

    private func moveSelection(_ direction: CandidateNavigationDirection) {
        guard candidateCount > 0 else { return }
        if selectedIndex == nil {
            selectedIndex = 0
        } else if let directionalSelection {
            selectedIndex = directionalSelection(selectedIndex, direction)
        }
        selectionChanged?(selectedIndex)
    }
}
