import json
import os
import subprocess
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
    def candidates(
        self,
        value,
        timestamp="2026-09-20T00:00:00+09:00",
        timezone="Asia/Tokyo",
    ):
        script = EXTENSIONS / "datetime.js"
        runner = f"""
const fs = require("fs")
eval(fs.readFileSync({json.dumps(str(script))}, "utf8"))
process.stdout.write(JSON.stringify(candidates({{
  input: {json.dumps(value)},
  timestamp: {json.dumps(timestamp)},
  settings: {{ dateTimeCandidatesEnabled: ["true"] }}
}})))
"""
        environment = os.environ.copy()
        environment["TZ"] = timezone
        completed = subprocess.run(
            ["node", "-e", runner],
            check=True,
            capture_output=True,
            text=True,
            env=environment,
        )
        return json.loads(completed.stdout)

    def values(self, value):
        return [
            candidate["value"] if isinstance(candidate, dict) else candidate
            for candidate in self.candidates(value)
        ]

    def test_suggests_parenthesized_weekdays_for_multiple_readings(self):
        readings = {
            "nichi": "(日)", "nichiyou": "(日)", "nichiyoubi": "(日)",
            "getsu": "(月)", "getsuyou": "(月)", "getsuyoubi": "(月)",
            "ka": "(火)", "kayou": "(火)", "kayoubi": "(火)",
            "sui": "(水)", "suiyou": "(水)", "suiyoubi": "(水)",
            "moku": "(木)", "mokuyou": "(木)", "mokuyoubi": "(木)",
            "kin": "(金)", "kinyou": "(金)", "kinyoubi": "(金)",
            "do": "(土)", "doyou": "(土)", "doyoubi": "(土)",
        }
        for reading, expected in readings.items():
            with self.subTest(reading=reading):
                self.assertEqual(self.values(reading), [expected])

    def test_parses_month_and_day_using_the_current_year(self):
        self.assertEqual(self.values("9/1"), ["20260901", "9/1(火)"])
        self.assertEqual(self.values("0906"), ["20260906", "9/6(日)"])

    def test_parses_eight_digit_date_with_an_explicit_year(self):
        self.assertEqual(self.values("20260906"), ["9/6(日)"])

    def test_rejects_nonexistent_dates(self):
        self.assertEqual(self.values("2/30"), [])
        self.assertEqual(self.values("20260229"), [])

    def test_marks_relative_dates_and_current_times_as_dynamic(self):
        for reading in ("kyou", "ashita", "kinou", "ima"):
            with self.subTest(reading=reading):
                candidates = self.candidates(reading)
                self.assertTrue(candidates)
                self.assertTrue(all(
                    candidate["kind"] == "dynamic_date_time"
                    for candidate in candidates
                ))
                self.assertTrue(all(
                    candidate["preferenceID"].startswith("dynamic_")
                    for candidate in candidates
                ))

    def test_dynamic_candidate_ids_depend_on_reading_and_format_not_value(self):
        october = self.candidates(
            "kyou",
            timestamp="2026-10-31T12:00:00+09:00",
        )
        november = self.candidates(
            "kyou",
            timestamp="2026-11-01T12:00:00+09:00",
        )
        tomorrow = self.candidates(
            "ashita",
            timestamp="2026-10-31T12:00:00+09:00",
        )

        self.assertNotEqual(
            [candidate["value"] for candidate in october],
            [candidate["value"] for candidate in november],
        )
        self.assertEqual(
            [candidate["preferenceID"] for candidate in october],
            [candidate["preferenceID"] for candidate in november],
        )
        self.assertNotEqual(
            [candidate["preferenceID"] for candidate in october],
            [candidate["preferenceID"] for candidate in tomorrow],
        )

    def test_relative_dates_follow_local_calendar_boundaries(self):
        cases = (
            ("ashita", "2026-10-31T23:30:00+09:00", "Asia/Tokyo", "20261101"),
            ("ashita", "2026-12-31T23:30:00+09:00", "Asia/Tokyo", "20270101"),
            ("kinou", "2024-03-01T00:30:00+09:00", "Asia/Tokyo", "20240229"),
            ("kyou", "2026-11-01T00:30:00+09:00", "Asia/Tokyo", "20261101"),
            ("kyou", "2026-10-31T16:30:00Z", "Asia/Tokyo", "20261101"),
            ("kyou", "2026-10-31T16:30:00Z", "UTC", "20261031"),
        )
        for reading, timestamp, timezone, expected in cases:
            with self.subTest(
                reading=reading,
                timestamp=timestamp,
                timezone=timezone,
            ):
                values = [
                    candidate["value"]
                    for candidate in self.candidates(
                        reading,
                        timestamp=timestamp,
                        timezone=timezone,
                    )
                ]
                self.assertEqual(values[0], expected)

    def test_keeps_entered_dates_weekdays_and_calendar_formats_static(self):
        for reading in ("9/1", "nichi", "calendar"):
            with self.subTest(reading=reading):
                self.assertTrue(all(
                    isinstance(candidate, str)
                    for candidate in self.candidates(reading)
                ))

    def test_date_formats_are_defined_only_in_datetime_extension(self):
        datetime_source = (EXTENSIONS / "datetime.js").read_text()

        self.assertIn('const dateFormats =', datetime_source)
        self.assertIn('input === "calendar"', datetime_source)

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
