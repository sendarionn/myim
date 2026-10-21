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


if __name__ == "__main__":
    unittest.main()
