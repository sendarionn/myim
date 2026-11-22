import re
import unittest
from pathlib import Path


SOURCES = Path(__file__).parents[2] / "Sources" / "MyIMEMacOS"


class PanelSizeTests(unittest.TestCase):
    def test_calendar_is_as_large_as_the_emoji_panel(self):
        calendar = (SOURCES / "CalendarWindowController.swift").read_text(
            encoding="utf-8"
        )
        size = re.search(
            r"let gridSize = NSSize\(width: (\d+), height: (\d+)\)", calendar
        )
        self.assertEqual(size.groups(), ("240", "240"))


if __name__ == "__main__":
    unittest.main()
