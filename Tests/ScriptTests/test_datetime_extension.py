import unittest
from pathlib import Path


EXTENSIONS = (
    Path(__file__).parents[2]
    / "Sources"
    / "MyIMEMacOS"
    / "Resources"
    / "Extensions"
)
REPOSITORY = Path(__file__).parents[2]


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

    def test_swift_does_not_keep_a_second_datetime_candidate_generator(self):
        generator = (
            REPOSITORY
            / "Sources"
            / "MyIMECore"
            / "DateTimeCandidateGenerator.swift"
        )
        client_source = (
            REPOSITORY
            / "Sources"
            / "MyIMEMacOS"
            / "JavaScriptExtensionClient.swift"
        ).read_text()

        self.assertFalse(generator.exists())
        self.assertNotIn('"dateFormats"', client_source)
        self.assertNotIn('"timeFormats"', client_source)
        self.assertNotIn('"dateTimeFormats"', client_source)

    def test_search_destinations_are_defined_by_extensions(self):
        input_controller = (
            REPOSITORY
            / "Sources"
            / "MyIMEMacOS"
            / "InputController.swift"
        ).read_text()
        web_search = (EXTENSIONS / "websearch.js").read_text()
        external_information = (
            EXTENSIONS / "external-information.js"
        ).read_text()

        self.assertNotIn("WebSearchTemplate", input_controller)
        self.assertIn("@myim-url", web_search)
        self.assertIn("@myim-url", external_information)


if __name__ == "__main__":
    unittest.main()
