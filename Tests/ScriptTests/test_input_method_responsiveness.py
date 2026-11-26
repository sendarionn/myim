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
        self.capture = (SOURCES / "PanelKeyCapture.swift").read_text(
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
        self.assertIn("PanelKeyCapture.selectionBracket.end()", finish)
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
        self.assertIn("guard PanelKeyCapture.selectionBracket.begin()", begin)
        self.assertLess(
            begin.index("PanelKeyCapture.selectionBracket.begin()"),
            begin.index("selectionBracketChoice = SelectionBracketChoice("),
        )
        self.assertIn("end()\n                return false", self.capture)

    def test_captures_the_navigation_keys(self):
        for key in ["kVK_LeftArrow", "kVK_UpArrow", "kVK_RightArrow",
                    "kVK_DownArrow", "kVK_Tab, 0", "kVK_Tab, shiftKey",
                    "kVK_Return", "kVK_ANSI_KeypadEnter", "kVK_Escape"]:
            with self.subTest(key=key):
                self.assertIn(key, self.capture)


class BookmarkPanelKeyCaptureTests(unittest.TestCase):
    """The bookmark panel takes its keys from the application only while it
    is shown, so Chrome and VS Code do not also move their cursor or focus"""

    def setUp(self):
        self.controller = (SOURCES / "InputController.swift").read_text(
            encoding="utf-8"
        )
        self.capture = (SOURCES / "PanelKeyCapture.swift").read_text(
            encoding="utf-8"
        )

    def body(self, signature):
        start = self.controller.index(signature)
        return self.controller[start:self.controller.index("\n    }\n", start)]

    def test_captures_the_navigation_keys_and_backspace(self):
        start = self.capture.index("static let bookmark = PanelKeyCapture(")
        bookmark = self.capture[start:self.capture.index("\n    )\n", start)]
        self.assertIn("navigationKeys + [(kVK_Delete, 0, .deleteBackward)]",
                      bookmark)
        self.assertIn("handleBookmarkPanelCommand", bookmark)

    def test_panels_use_their_own_hot_key_signature(self):
        signatures = [
            line.split("signature: ")[1].rstrip(",")
            for line in self.capture.splitlines()
            if line.strip().startswith("signature: 0x")
        ]
        self.assertEqual(len(signatures), len(set(signatures)))
        # The bracket choice, the input history and the bookmark search
        self.assertEqual(len(signatures), 3)

    def test_the_panel_opens_only_with_every_key_taken(self):
        begin = self.body("private func beginBookmarkSearch(")
        self.assertLess(
            begin.index("guard PanelKeyCapture.bookmark.begin()"),
            begin.index("bookmarkSearchSession.begin()"),
        )
        # The bracket panel takes the same keys
        self.assertLess(
            begin.index("finishSelectionBracketChoice()"),
            begin.index("guard PanelKeyCapture.bookmark.begin()"),
        )

    def test_every_close_releases_the_keys(self):
        self.assertIn("PanelKeyCapture.bookmark.end()",
                      self.body("private func clearBookmarkSearch("))
        for caller in [
            "private func resetTransientInteractionState()",
            "private func toggleEmojiWindow(client sender: Any)",
            "private func beginSelectionBracketChoice(",
            "private func commitSelectedBookmarkFormat(",
            "override func deactivateServer(",
        ]:
            with self.subTest(caller=caller):
                self.assertIn("clearBookmarkSearch()", self.body(caller))

    def test_search_text_is_converted_as_usual_and_kept_out_of_the_document(self):
        commit = self.body("    private func commit(\n")
        self.assertLess(commit.index("commitToBookmarkSearch(value, client: sender)"),
                        commit.index("textClient.insertText("))
        prefix = self.body("private var compositionPrefix: String {")
        self.assertIn("return bookmarkSearchSession.query", prefix)
        for recorder in ["private func recordSelectedCandidate()",
                         "private func learnUnselectedInput("]:
            with self.subTest(recorder=recorder):
                self.assertIn("!bookmarkSearchSession.isSearching",
                              self.body(recorder))

    def test_panel_takes_keys_only_while_nothing_is_converted(self):
        update = self.body("private func updateBookmarkSearchPresentation()")
        self.assertIn("let capturesKeys = inputBuffer.isEmpty", update)
        self.assertIn("PanelKeyCapture.bookmark.end()", update)
        handle = self.body("override func handle(_ event")
        self.assertIn("updateBookmarkSearchPresentation()", handle)

    def test_bookmarks_have_their_own_panel_beside_the_candidates(self):
        show = self.body("private func showBookmarkCandidates()")
        self.assertIn("bookmarkPanel.showList(", show)
        self.assertIn("beside: occupiedConversionFrame", show)
        self.assertNotIn("primaryCandidatePanel.show(", show)
        self.assertNotIn("caption:", show)

    def test_formats_open_beside_the_titles_and_keep_the_preview(self):
        formats = self.body("private func showBookmarkFormats()")
        self.assertLess(formats.index("showBookmarkCandidates()"),
                        formats.index("bookmarkPanel.showFormats("))
        preview = self.body("private func updateBookmarkPreview()")
        self.assertIn("bookmarkSearchSession.formatBookmark", preview)
        self.assertIn("previewWindow.moveInformationPanel(beside: panelFrame)",
                      preview)

    def test_ending_the_search_removes_the_search_text(self):
        clear = self.body("private func clearBookmarkSearch(")
        self.assertIn("clearCompositionForSystemPaste(in: sender)", clear)

    def test_captured_keys_run_only_for_the_original_input_target(self):
        handler = self.body("static func handleBookmarkPanelCommand(")
        self.assertIn("bookmarkInsertionContext?.matches(client) == true",
                      handler)
        self.assertIn("controller.clearBookmarkSearch()", handler)

    def test_a_key_the_hot_key_missed_is_still_handled(self):
        # A key taken as a hot key never reaches the input method, so one
        # that does, such as an arrow the hot key missed, is handled there
        event = self.body("private func handleBookmarkSearchEvent(")
        self.assertNotIn("PanelKeyCapture.capturedKeyCodes.contains", event)
        self.assertIn("handleBookmarkCommand(.next, client: sender)", event)
        escape = self.controller[
            self.controller.index('"cancelOperation:",\n           bookmarkSearchSession.isActive'):
        ][:300]
        self.assertIn("if !PanelKeyCapture.bookmark.isCapturing", escape)

    def test_delete_goes_back_or_closes_like_esc_once_the_text_is_gone(self):
        command = self.body("private func handleBookmarkCommand(")
        self.assertIn("handleBookmarkDelete(client: sender, isRepeat: isRepeat)",
                      command)
        delete = self.body("private func handleBookmarkDelete(")
        self.assertLess(delete.index("bookmarkSearchSession.deleteBackward()"),
                        delete.index("guard !isRepeat else { return }"))
        self.assertLess(delete.index("guard !isRepeat else { return }"),
                        delete.index("handleBookmarkEscape(client: sender)"))
        event = self.body("private func handleBookmarkSearchEvent(")
        self.assertIn("isRepeat: event.isARepeat", event)

