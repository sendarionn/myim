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
            self.candidates(14, 35),
            ["14:35", "14:35", "14時35分", "1435", "2:35 PM"],
        )

    def test_preserves_midnight_and_one_minute_precision(self):
        self.assertEqual(
            self.candidates(0, 7),
            ["00:07", "0:07", "0時7分", "0007", "12:07 AM"],
        )

    def test_rejects_invalid_values(self):
        self.assertEqual(self.candidates(24, 0), [])
        self.assertEqual(self.candidates(10, 60), [])


if __name__ == "__main__":
    unittest.main()
