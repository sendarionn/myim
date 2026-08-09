import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[2] / "Scripts" / "convert-tkgje-semantic-dictionary.py"
SPEC = importlib.util.spec_from_file_location("convert_tkgje_semantic_dictionary", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ConvertTKGJESemanticDictionaryTests(unittest.TestCase):
    def test_extracts_only_semantic_fields(self):
        with tempfile.TemporaryDirectory() as directory:
            repository = Path(directory)
            (repository / "entries" / "00000").mkdir(parents=True)
            (repository / "entries_index.json").write_text(
                json.dumps({"entries": [{
                    "id": "00396_taberu",
                    "vocabulary_tier": "basic",
                }]}),
                encoding="utf-8",
            )
            (repository / "entries" / "00000" / "00396_taberu.json").write_text(
                json.dumps({
                    "headword": "{食|た}べる",
                    "part_of_speech": "verb (ichidan)",
                    "gloss": "to eat",
                    "definitions": [{
                        "gloss": "to consume food",
                        "explanation": "The common verb for eating",
                    }],
                    "examples": [{"japanese": "ご飯を食べる"}],
                    "metadata": {"ai_model": "unused"},
                }, ensure_ascii=False),
                encoding="utf-8",
            )
            output = repository / "semantic.jsonl"
            entry_count, missing_count = MODULE.convert(
                repository,
                output,
                {"basic"},
            )
            self.assertEqual((entry_count, missing_count), (1, 0))
            result = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(result["headword"], "食べる")
            self.assertEqual(result["reading"], "taberu")
            self.assertEqual(result["vocabularyTier"], "basic")
            self.assertEqual(result["glosses"], ["to eat", "to consume food"])
            self.assertEqual(result["explanations"], ["The common verb for eating"])
            self.assertNotIn("examples", result)
            self.assertNotIn("metadata", result)


if __name__ == "__main__":
    unittest.main()
