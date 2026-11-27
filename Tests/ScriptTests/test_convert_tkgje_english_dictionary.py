import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[2] / "Scripts" / "convert-tkgje-english-dictionary.py"
SPEC = importlib.util.spec_from_file_location("convert_tkgje_english_dictionary", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ConvertTKGJEEnglishDictionaryTests(unittest.TestCase):
    def convert(self, entries):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "entries_index.json"
            output = Path(directory) / "dictionary.tsv"
            source.write_text(json.dumps({"entries": entries}, ensure_ascii=False), encoding="utf-8")
            MODULE.convert(source, output)
            return [line.split("\t") for line in output.read_text(encoding="utf-8").splitlines()]

    def test_short_glosses_become_candidates_and_verbs_lose_to(self):
        lines = self.convert([
            {"id": "00426_yomu", "reading": "よむ", "gloss": "to read", "vocabulary_tier": "basic"},
            {"id": "14186_yomu", "reading": "よむ", "gloss": "to compose (a poem), to recite",
             "vocabulary_tier": "general"},
            {"id": "02269_ringo", "reading": "りんご", "gloss": "apple", "vocabulary_tier": "core"},
        ])
        self.assertIn(["ringo", "apple"], lines)
        # Explanations in parentheses are not candidates
        self.assertEqual([word for reading, word in lines if reading == "yomu"], ["read", "recite"])

    def test_each_word_of_a_reading_comes_before_the_rest_of_another(self):
        lines = self.convert([
            {"id": "01", "reading": "けんとう", "gloss": "estimate, guess, aim", "vocabulary_tier": "basic"},
            {"id": "02", "reading": "けんとう", "gloss": "examination", "vocabulary_tier": "core"},
            {"id": "03", "reading": "けんとう", "gloss": "good fight", "vocabulary_tier": "general"},
        ])
        self.assertEqual([word for _, word in lines], ["estimate", "examination", "good fight"])


if __name__ == "__main__":
    unittest.main()
