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
    / "nextinput.js"
)


class NextInputExtensionTests(unittest.TestCase):
    def candidates(self, value):
        runner = f"""
const fs = require("fs")
eval(fs.readFileSync({json.dumps(str(SCRIPT))}, "utf8"))
process.stdout.write(JSON.stringify(nextInputCandidates({{ input: {json.dumps(value)} }})))
"""
        completed = subprocess.run(
            ["node", "-e", runner],
            check=True,
            capture_output=True,
            text=True,
        )
        return json.loads(completed.stdout)

    def test_suggests_units_after_ascii_number(self):
        self.assertEqual(self.candidates("100"), [
            "年", "円", "個", "人", "回", "日", "時", "分", "秒"
        ])

    def test_suggests_units_after_full_width_number(self):
        self.assertIn("円", self.candidates("１０００"))

    def test_does_not_suggest_units_after_non_numeric_input(self):
        self.assertEqual(self.candidates("よろしく"), [])


if __name__ == "__main__":
    unittest.main()
