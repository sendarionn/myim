import re
import unittest
from pathlib import Path


SOURCES = Path(__file__).parents[2] / "Sources" / "MyIMEMacOS"


class PanelSizeTests(unittest.TestCase):
    def test_both_panels_declare_the_same_target_size(self):
        calendar = (SOURCES / "CalendarWindowController.swift").read_text(
            encoding="utf-8"
        )
        calendar_size = re.search(
            r"let gridSize = NSSize\(width: (\d+), height: (\d+)\)", calendar
        )
        emoji = (SOURCES / "EmojiWindowController.swift").read_text(
            encoding="utf-8"
        )
        emoji_width = re.search(r"panelWidth: CGFloat = (\d+)", emoji)
        self.assertEqual(calendar_size.groups(), ("240", "240"))
        self.assertEqual(emoji_width.group(1), "240")

    def test_runtime_verifier_is_available(self):
        runtime_test = Path(__file__).parents[1] / "RuntimeTests" / "test_panel_sizes.sh"
        self.assertTrue(runtime_test.exists())


if __name__ == "__main__":
    unittest.main()
