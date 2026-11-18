import re
import unittest
from pathlib import Path


SOURCES = Path(__file__).parents[2] / "Sources" / "MyIMEMacOS"


class TimeRangePanelTests(unittest.TestCase):
    """The range rail shares the time panel, its keys and its insertion"""

    def setUp(self):
        self.view = (SOURCES / "TimeRangeView.swift").read_text(encoding="utf-8")
        self.window = (SOURCES / "TimeWindowController.swift").read_text(
            encoding="utf-8"
        )
        self.controller = (SOURCES / "InputController.swift").read_text(
            encoding="utf-8"
        )

    def body(self, source, signature):
        start = source.index(signature)
        return source[start:source.index("\n    }\n", start)]

    def test_keys_the_input_method_receives_go_to_the_rail(self):
        handle = self.body(self.window, "func handleKeyEvent(")
        self.assertIn("rangeView.handleKey(event)", handle)
        self.assertTrue(handle.rstrip().endswith("return true"))

    def test_pressing_the_shortcut_again_switches_the_clock_to_the_rail(self):
        shortcut = self.body(self.window, "private func handleShortcut()")
        self.assertIn("if !isShowingRange, !inputView.isShowingFormats {\n"
                      "            showRange()", shortcut)
        handle = self.body(self.window, "func handleKeyEvent(")
        self.assertIn("handleShortcut()", handle)
        # Keys the panel receives itself take the same route
        self.assertIn("panel.shortcutAction = { [weak self] in "
                      "self?.handleShortcut() }", self.window)

    def test_both_views_take_the_panel_size_after_a_resize(self):
        # Autoresizing left the range view with no height once the panel
        # shrank from the clock's height to the rail's
        resize = self.body(self.window, "private func resize(toHeight")
        self.assertLess(resize.index("panel.setContentSize("),
                        resize.index("rangeView.frame = bounds"))
        self.assertIn("inputView.frame = bounds", resize)

    def test_escape_closes_the_rail_without_inserting(self):
        escape = self.body(self.window, "func handleEscape()")
        self.assertIn("if isShowingRange {\n            cancelSelection()",
                      escape)

    def test_range_is_inserted_from_time_js_after_the_panel_closes(self):
        insert = self.body(self.controller, "private func insertTimeRange(")
        self.assertIn("timeRangeText(range)", insert)
        self.assertLess(insert.index("self.clearTimeSelection()"),
                        insert.index("self.commit(text, to: sender)"))
        result = self.body(self.controller, "private func handleTimePanelResult(")
        self.assertIn("insertTimeRange(range, client: sender)", result)

    def test_only_voiceover_names_describe_the_parts(self):
        drawn = re.findall(r'drawCentered\(\s*"([^"]*)"', self.view)
        self.assertEqual(drawn, ["〜"])
        for label in ["開始時刻", "終了時刻", "挿入"]:
            self.assertIn(f'"{label}"', self.view)

    def test_each_knob_is_taken_from_its_own_side_of_the_rail(self):
        knob = self.body(self.view, "private func knobEdge(")
        self.assertIn("point.y >= railY", knob)
        self.assertIn("return .start", knob)
        self.assertIn("point.y < railY", knob)
        self.assertIn("return .end", knob)


if __name__ == "__main__":
    unittest.main()
