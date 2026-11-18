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

    def test_each_shortcut_switches_between_the_clock_and_the_rail(self):
        shortcut = self.body(self.window, "private func handleShortcut()")
        self.assertIn("guard !inputView.isShowingFormats else { return }",
                      shortcut)
        self.assertIn("showClock()", shortcut)
        self.assertIn("showRange()", shortcut)
        self.assertNotIn("cancelSelection()", shortcut)
        handle = self.body(self.window, "func handleKeyEvent(")
        self.assertIn("handleShortcut()", handle)
        # Keys the panel receives itself take the same route
        self.assertIn("panel.shortcutAction = { [weak self] in "
                      "self?.handleShortcut() }", self.window)

    def test_the_clock_has_no_range_button(self):
        self.assertNotIn("rangeButton", self.window)

    def test_escape_closes_the_rail_without_inserting(self):
        escape = self.body(self.window, "func handleEscape()")
        self.assertIn("if isShowingRange {\n            cancelSelection()",
                      escape)

    def test_range_formats_are_chosen_like_those_of_a_time(self):
        load = self.body(self.controller, "private func loadTimeFormats(")
        self.assertIn("timeRangeFormats(range)", load)
        self.assertIn("accepts(formatsFor: range)", load)
        self.assertIn("title: title,", self.controller)
        back = self.body(self.controller, "private func returnToTimeSelection(")
        self.assertIn("resumeTimeRangeSelection(", back)

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
