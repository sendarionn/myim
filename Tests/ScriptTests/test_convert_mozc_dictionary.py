import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[2] / "Scripts" / "convert-mozc-dictionary.py"
SPEC = importlib.util.spec_from_file_location("convert_mozc_dictionary", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ConvertMozcDictionaryTests(unittest.TestCase):
    def test_deduplicates_and_orders_candidates_by_cost(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            (source / "dictionary00.txt").write_text(
                "かくじゅう\t1\t1\t5000\t角十\n"
                "かくじゅう\t1\t1\t1000\t拡充\n"
                "かくじゅう\t1\t1\t2000\t拡充\n"
                "かくじゅう\t1\t1\t100\tかくじゅう\n",
                encoding="utf-8",
            )
            result = MODULE.convert(source, maximum_candidates=2)
            self.assertEqual(result["かくじゅう"], ["拡充", "角十"])

    def test_rejects_invalid_candidate_limit(self):
        with self.assertRaises(ValueError):
            MODULE.convert(Path("."), maximum_candidates=0)


if __name__ == "__main__":
    unittest.main()
