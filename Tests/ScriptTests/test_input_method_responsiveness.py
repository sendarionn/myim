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
