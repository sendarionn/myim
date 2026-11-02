import json
import subprocess
import unittest
from datetime import datetime
from pathlib import Path


SCRIPT = (
    Path(__file__).parents[2]
    / "Sources"
    / "MyIMEMacOS"
    / "Resources"
    / "Extensions"
    / "eto.js"
)


def local_timestamp(year, month, day, hour=12):
    return int(datetime(year, month, day, hour).timestamp() * 1000)


class EtoExtensionTests(unittest.TestCase):
    def candidates(self, value, timestamp=None):
        timestamp = timestamp or local_timestamp(2026, 6, 1)
        runner = f"""
const fs = require("fs")
eval(fs.readFileSync({json.dumps(str(SCRIPT))}, "utf8"))
process.stdout.write(JSON.stringify(candidates({{
  input: {json.dumps(value)},
  timestamp: {timestamp}
}})))
"""
        completed = subprocess.run(
            ["node", "-e", runner],
            check=True,
            capture_output=True,
            text=True,
        )
        return json.loads(completed.stdout)

    def values(self, value, timestamp=None):
        return [
            candidate["value"] if isinstance(candidate, dict) else candidate
            for candidate in self.candidates(value, timestamp)
        ]

    def test_every_reading_gives_its_kanji_and_emoji(self):
        expected = {
            "ne": ["子", "🐭"], "nezumi": ["子", "🐭"],
            "ushi": ["丑", "🐂"], "tora": ["寅", "🐯"],
            "u": ["卯", "🐰"], "usagi": ["卯", "🐰"],
            "tatsu": ["辰", "🐉"], "mi": ["巳", "🐍"], "hebi": ["巳", "🐍"],
            "uma": ["午", "🐴"], "hitsuji": ["未", "🐑"],
            "saru": ["申", "🐒"], "tori": ["酉", "🐓"], "inu": ["戌", "🐕"],
            "i": ["亥", "🐗"], "inoshishi": ["亥", "🐗"],
        }
        for reading, candidates in expected.items():
            with self.subTest(reading=reading):
                self.assertEqual(self.values(reading), candidates)

    def test_readings_follow_the_dictionary_words_and_learn_as_text(self):
        for candidate in self.candidates("tora"):
            self.assertEqual(candidate["kind"], "supplementary")
            self.assertNotIn("preferenceID", candidate)

    def test_given_year_gives_its_branch(self):
        expected = {
            "eto2024": ["辰", "🐉"], "eto2025": ["巳", "🐍"],
            "eto2026": ["午", "🐴"], "eto2027": ["未", "🐑"],
            "eto2028": ["申", "🐒"], "eto2030": ["戌", "🐕"],
            "eto2032": ["子", "🐭"], "eto2020": ["子", "🐭"],
            "eto2019": ["亥", "🐗"],
        }
        for value, candidates in expected.items():
            with self.subTest(value=value):
                self.assertEqual(self.values(value), candidates)

    def test_branch_repeats_every_twelve_years(self):
        for year in [1, 1999, 2026, 9987]:
            with self.subTest(year=year):
                self.assertEqual(
                    self.values(f"eto{year:04d}"),
                    self.values(f"eto{year + 12:04d}"),
                )

    def test_first_and_last_years_are_calculated(self):
        # 0001 is 2019 years before 2020, which is 3 short of 168 cycles
        self.assertEqual(self.values("eto0001"), ["酉", "🐓"])
        # 9999 is 7979 years after 2020, 11 more than 664 cycles
        self.assertEqual(self.values("eto9999"), ["亥", "🐗"])

    def test_invalid_or_partial_years_give_nothing(self):
        for value in [
            "eto0000", "eto202", "eto20261", "eto2O26", "eto-2026",
            "etoo", "et", "eto 2026",
        ]:
            with self.subTest(value=value):
                self.assertEqual(self.candidates(value), [])

    def test_this_year_follows_the_local_date(self):
        new_year_eve = self.values("eto", local_timestamp(2026, 12, 31, 23))
        new_year = self.values("eto", local_timestamp(2027, 1, 1, 0))

        self.assertEqual(new_year_eve[:2], ["午", "🐴"])
        self.assertEqual(new_year[:2], ["未", "🐑"])

    def test_this_year_keeps_the_other_eto_candidates_after_the_dictionary(self):
        for candidate in self.candidates("eto")[2:]:
            self.assertEqual(candidate["kind"], "supplementary")

        self.assertEqual(
            self.values("eto")[2:],
            [
                "十二支",
                "子丑寅卯辰巳午未申酉戌亥",
                "🐭🐂🐯🐰🐉🐍🐴🐑🐒🐓🐕🐗",
            ],
        )

    def test_year_branches_learn_their_kind_rather_than_the_text(self):
        this_year = self.candidates("eto")[:2]
        given_2026 = self.candidates("eto2026")
        given_2027 = self.candidates("eto2027")

        for candidate in this_year + given_2026:
            self.assertEqual(candidate["kind"], "dynamic_date_time")
        self.assertEqual(
            [candidate["preferenceID"] for candidate in this_year],
            ["dynamic_eto:current:kanji", "dynamic_eto:current:emoji"],
        )
        # The emoji chosen for 2026 is preferred for 2027 by the same ID
        self.assertEqual(
            [candidate["preferenceID"] for candidate in given_2026],
            [candidate["preferenceID"] for candidate in given_2027],
        )

    def test_declares_only_the_prefixes_of_its_readings(self):
        source = SCRIPT.read_text(encoding="utf-8")
        prefixes = [
            line.split()[-1]
            for line in source.splitlines()
            if line.startswith("// @myim-prefix ")
        ]
        readings = (
            ["eto"]
            + [
                "ne", "nezumi", "ushi", "tora", "u", "usagi", "tatsu", "mi",
                "hebi", "uma", "hitsuji", "saru", "tori", "inu", "i",
                "inoshishi",
            ]
        )
        for reading in readings:
            with self.subTest(reading=reading):
                self.assertTrue(
                    any(reading.startswith(prefix) for prefix in prefixes)
                )


if __name__ == "__main__":
    unittest.main()
