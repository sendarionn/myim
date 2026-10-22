import json
import subprocess
import unittest
from pathlib import Path


SCRIPT = (
    Path(__file__).parents[2]
    / "Sources"
    / "MyIMEMacOS"
    / "Resources"
    / "Extensions"
    / "time.js"
)


class TimeExtensionTests(unittest.TestCase):
    def candidates(self, hour, minute):
        runner = f"""
const fs = require("fs")
eval(fs.readFileSync({json.dumps(str(SCRIPT))}, "utf8"))
process.stdout.write(JSON.stringify(candidates({{
  input: "time",
  parameters: {{ hour: {json.dumps(str(hour))}, minute: {json.dumps(str(minute))} }}
}})))
"""
        completed = subprocess.run(
            ["node", "-e", runner],
            check=True,
            capture_output=True,
            text=True,
        )
        return json.loads(completed.stdout)

    def direct_candidates(self, value):
        runner = f"""
const fs = require("fs")
eval(fs.readFileSync({json.dumps(str(SCRIPT))}, "utf8"))
process.stdout.write(JSON.stringify(candidates({{
  input: {json.dumps(value)},
  parameters: {{}}
}})))
"""
        completed = subprocess.run(
            ["node", "-e", runner],
            check=True,
            capture_output=True,
            text=True,
        )
        return json.loads(completed.stdout)

    def test_formats_selected_time_in_definition_order(self):
        self.assertEqual(
            self.candidates(14, 5),
            ["14:05", "14時05分"],
        )

    def test_preserves_midnight_and_one_minute_precision(self):
        self.assertEqual(
            self.candidates(0, 7),
            ["00:07", "00時07分"],
        )

    def test_adds_half_hour_only_for_thirty_minutes(self):
        self.assertEqual(
            self.candidates(14, 30),
            ["14:30", "14時30分", "14時半"],
        )
        self.assertEqual(
            self.candidates(9, 30),
            ["09:30", "09時30分", "9時半"],
        )
        self.assertNotIn("14時半", self.candidates(14, 25))

    def test_rejects_invalid_values(self):
        self.assertEqual(self.candidates(24, 0), [])
        self.assertEqual(self.candidates(10, 60), [])

    def test_formats_direct_time_without_repeating_the_input(self):
        expected = {
            "00:00": ["00時00分"],
            "00:30": ["00時30分", "0時半"],
            "09:05": ["09時05分"],
            "09:30": ["09時30分", "9時半"],
            "14:30": ["14時30分", "14時半"],
            "23:59": ["23時59分"],
        }
        for value, candidates in expected.items():
            with self.subTest(value=value):
                self.assertEqual(self.direct_candidates(value), candidates)
                self.assertNotIn(value, candidates)

    def test_formats_direct_time_typed_without_the_colon(self):
        expected = {
            "0000": ["00:00", "00時00分"],
            "0930": ["09:30", "09時30分", "9時半"],
            "1100": ["11:00", "11時00分"],
            "1300": ["13:00", "13時00分"],
            "2359": ["23:59", "23時59分"],
        }
        for value, candidates in expected.items():
            with self.subTest(value=value):
                self.assertEqual(self.direct_candidates(value), candidates)

    def test_rejects_invalid_or_partial_direct_time(self):
        for value in [
            "24:00", "12:60", "99:99", "9:30", "14:3",
            "14:", "abc14:30", "14:30abc",
            "2400", "1260", "930", "13000", "14::30", "1430abc",
        ]:
            with self.subTest(value=value):
                self.assertEqual(self.direct_candidates(value), [])

    def test_declares_only_relevant_direct_input_prefixes(self):
        source = SCRIPT.read_text()

        self.assertIn("// @myim-prefix time", source)
        self.assertIn("// @myim-prefix 0", source)
        self.assertIn("// @myim-prefix 1", source)
        self.assertIn("// @myim-prefix 2", source)


if __name__ == "__main__":
    unittest.main()
