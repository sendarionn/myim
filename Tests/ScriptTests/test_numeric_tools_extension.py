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
    / "numeric-tools.js"
)


class NumericToolsExtensionTests(unittest.TestCase):
    def candidates(self, value):
        runner = f"""
const fs = require("fs")
eval(fs.readFileSync({json.dumps(str(SCRIPT))}, "utf8"))
process.stdout.write(JSON.stringify(candidates({{ input: {json.dumps(value)} }})))
"""
        completed = subprocess.run(
            ["node", "-e", runner],
            check=True,
            capture_output=True,
            text=True,
        )
        return json.loads(completed.stdout)

    def test_converts_integer_to_binary(self):
        self.assertEqual(self.candidates("10"), ["0b1010"])
        self.assertEqual(self.candidates("-5"), ["-0b101"])

    def test_converts_metric_length_to_imperial_units(self):
        self.assertEqual(
            self.candidates("10cm"),
            ["約3.9in", "約0.3ft", "約0.1yd"],
        )
        self.assertIn("約0.6mi", self.candidates("1km"))

    def test_reduces_fraction(self):
        self.assertEqual(self.candidates("8/12"), ["2/3"])
        self.assertEqual(self.candidates("-10 / 15"), ["-2/3"])

    def test_ignores_irreducible_or_invalid_fraction(self):
        self.assertEqual(self.candidates("2/3"), [])
        self.assertEqual(self.candidates("1/0"), [])


if __name__ == "__main__":
    unittest.main()
