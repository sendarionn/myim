import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[2] / "Scripts" / "convert-tkgje-dictionary.py"
SPEC = importlib.util.spec_from_file_location("convert_tkgje_dictionary", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ConvertTKGJEDictionaryTests(unittest.TestCase):
    def test_normalizes_alternatives_and_placeholder(self):
        document = {
            "entries": [
                {
                    "id": "basic_hayai",
                    "headword": "速い／早い",
                    "vocabulary_tier": "basic",
                },
                {
                    "id": "basic_nado",
                    "headword": "〜など",
                    "vocabulary_tier": "basic",
                },
            ]
        }
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "entries_index.json"
            output = Path(directory) / "dictionary.tsv"
            source.write_text(json.dumps(document, ensure_ascii=False), encoding="utf-8")
            reading_count, candidate_count = MODULE.convert(
                source,
                output,
                set(MODULE.TIER_ORDER),
            )
            self.assertEqual(reading_count, 2)
            self.assertEqual(candidate_count, 3)
            self.assertEqual(
                output.read_text(encoding="utf-8"),
                "hayai\n 速い\n 早い\n\nnado\n など\n",
            )


if __name__ == "__main__":
    unittest.main()
