import unittest
from pathlib import Path


EXTENSIONS = (
    Path(__file__).parents[2]
    / "Sources"
    / "MyIMEMacOS"
    / "Resources"
    / "Extensions"
)


class DateTimeExtensionTests(unittest.TestCase):
    def test_date_formats_are_defined_only_in_datetime_extension(self):
        datetime_source = (EXTENSIONS / "datetime.js").read_text()
        calendar_source = (EXTENSIONS / "calendar.js").read_text()

        self.assertIn('const dateFormats =', datetime_source)
        self.assertIn('input === "calendar"', datetime_source)
        self.assertNotIn('const dateFormats =', calendar_source)
        self.assertNotIn('context.input !== "calendar"', calendar_source)

    def test_calendar_extension_only_formats_calendar_events(self):
        calendar_source = (EXTENSIONS / "calendar.js").read_text()

        self.assertIn('context.input === "calendar-event"', calendar_source)
        self.assertIn('formatCalendarEvent', calendar_source)


if __name__ == "__main__":
    unittest.main()
