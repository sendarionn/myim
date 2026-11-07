import unittest
from pathlib import Path


ROOT = Path(__file__).parents[2]
SOURCES = ROOT / "Sources" / "MyIMEMacOS"


class AccessibilityOffMainThreadTests(unittest.TestCase):
    """Accessibility messages block until the other application answers, so
    the main thread handling typing must never send them"""

    BLOCKING_CALLS = [
        "AXUIElementCopyAttributeValue",
        "AXObserverCreate",
        "AXObserverAddNotification",
    ]

    def test_only_the_focus_monitor_sends_accessibility_messages(self):
        for path in SOURCES.glob("*.swift"):
            if path.name == "AccessibilityFocusMonitor.swift":
                continue
            source = path.read_text(encoding="utf-8")
            for call in self.BLOCKING_CALLS:
                with self.subTest(file=path.name, call=call):
                    self.assertNotIn(call, source)

    def test_focus_monitor_runs_on_its_own_thread_with_a_timeout(self):
        source = (SOURCES / "AccessibilityFocusMonitor.swift").read_text(
            encoding="utf-8"
        )
        self.assertIn("Thread {", source)
        self.assertIn("CFRunLoopRun()", source)
        self.assertIn("AXUIElementSetMessagingTimeout", source)
        self.assertNotIn("CFRunLoopGetMain", source)

    def test_focus_is_watched_only_during_a_temporary_switch(self):
        source = (
            SOURCES / "PasswordInputSourceRecoveryController.swift"
        ).read_text(encoding="utf-8")
        self.assertIn("state.isAwaitingFocus", source)
        self.assertIn("generation == focusGeneration", source)


class HistoryWritesTests(unittest.TestCase):
    def test_switching_applications_does_not_wait_for_history_writes(self):
        source = (SOURCES / "InputController.swift").read_text(
            encoding="utf-8"
        )
        start = source.index("private func flushPendingHistoryWrites()")
        body = source[start:source.index("\n    }\n", start)]

        self.assertIn("flushInBackground()", body)
        self.assertNotIn(".flush()", body)


if __name__ == "__main__":
    unittest.main()


class SelectionBracketKeyCaptureTests(unittest.TestCase):
    """The bracket panel takes its keys from the application only while it
    is shown"""

    def setUp(self):
        self.controller = (SOURCES / "InputController.swift").read_text(
            encoding="utf-8"
        )
        self.capture = (SOURCES / "SelectionBracketKeyCapture.swift").read_text(
            encoding="utf-8"
        )

    def body(self, signature):
        start = self.controller.index(signature)
        return self.controller[start:self.controller.index("\n    }\n", start)]

    def test_one_shortcut_opens_the_panel(self):
        shortcuts = (SOURCES / "MyIMFeatureShortcut.swift").read_text(
            encoding="utf-8"
        )
        self.assertNotIn("case selectionBracketChoice", shortcuts)
        self.assertIn('"FeatureShortcut.selectionBracketChoice"', shortcuts)
        self.assertIn("MyIMFeatureShortcut.removeRetiredSettings()",
                      (SOURCES / "main.swift").read_text(encoding="utf-8"))
        self.assertNotIn("selectionBracketChoice.shortcut", self.controller)

    def test_every_close_releases_the_keys(self):
        finish = self.body("private func finishSelectionBracketChoice()")
        self.assertIn("SelectionBracketKeyCapture.shared.end()", finish)
        for caller in [
            "private func resetTransientInteractionState()",
            "private func toggleEmojiWindow(client sender: Any)",
            "private func handleSelectionBracketCommand(",
            "private func handleSelectionBracketKey(",
        ]:
            with self.subTest(caller=caller):
                self.assertIn("finishSelectionBracketChoice()",
                              self.body(caller))
        deactivate = self.controller[
            self.controller.index("EmojiGlobalHotKey.shared.deactivate()"):
        ][:200]
        self.assertIn("finishSelectionBracketChoice()", deactivate)

    def test_the_panel_opens_only_with_every_key_taken(self):
        begin = self.body("private func beginSelectionBracketChoice(")
        self.assertIn("guard SelectionBracketKeyCapture.shared.begin()", begin)
        self.assertLess(
            begin.index("SelectionBracketKeyCapture.shared.begin()"),
            begin.index("selectionBracketChoice = SelectionBracketChoice("),
        )
        self.assertIn("end()\n                return false", self.capture)

    def test_captures_the_navigation_keys(self):
        for key in ["kVK_LeftArrow", "kVK_UpArrow", "kVK_RightArrow",
                    "kVK_DownArrow", "kVK_Tab, 0", "kVK_Tab, shiftKey",
                    "kVK_Return", "kVK_ANSI_KeypadEnter", "kVK_Escape"]:
            with self.subTest(key=key):
                self.assertIn(key, self.capture)
