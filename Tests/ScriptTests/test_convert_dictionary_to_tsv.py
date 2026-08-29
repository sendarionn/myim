import subprocess
import tempfile
import unittest
from pathlib import Path


class ConvertDictionaryToTSVTests(unittest.TestCase):
    def test_converts_legacy_dictionary_and_keeps_tsv_lines(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "dictionary.txt"
            path.write_text(
                "miru\n 見る\n 観る\n\niku\t行く\n",
                encoding="utf-8",
            )

            subprocess.run(
                [
                    "ruby",
                    "Scripts/convert-dictionary-to-tsv.rb",
                    str(path),
                ],
                check=True,
            )

            self.assertEqual(
                path.read_text(encoding="utf-8"),
                "miru\t見る\nmiru\t観る\niku\t行く\n",
            )


if __name__ == "__main__":
    unittest.main()
