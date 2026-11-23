import re
import unittest
from pathlib import Path


SOURCES = Path(__file__).parents[2] / "Sources" / "MyIMEMacOS"


class PanelSizeTests(unittest.TestCase):
    def test_both_panels_use_the_shared_size_and_placement(self):
        positioning = (SOURCES / "InputPanelPositioning.swift").read_text(
            encoding="utf-8"
        )
        self.assertIn(
            "static let panelSize = NSSize(width: 240, height: 240)",
            positioning,
        )
        for name in ["CalendarWindowController.swift",
                     "EmojiWindowController.swift"]:
            source = (SOURCES / name).read_text(encoding="utf-8")
            with self.subTest(panel=name):
                self.assertIn("InputPanelPositioning.panelSize", source)
                self.assertIn("InputPanelPositioning.placement(", source)
                self.assertIn("applyInputPanelStyle()", source)

    def test_runtime_verifier_is_available(self):
        runtime_test = Path(__file__).parents[1] / "RuntimeTests" / "test_panel_sizes.sh"
        self.assertTrue(runtime_test.exists())


if __name__ == "__main__":
    unittest.main()
