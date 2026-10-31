import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[2] / "Scripts/generate-mozc-adjective-classes.py"
SPEC = importlib.util.spec_from_file_location(
    "generate_mozc_adjective_classes", SCRIPT
)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class GenerateMozcAdjectiveClassesTests(unittest.TestCase):
    def test_classifies_only_adjective_entries(self):
        self.assertEqual(
            MODULE.adjective_class("名詞,形容動詞語幹,*,*,*,*"),
            "na-adjective-stem",
        )
        self.assertEqual(
            MODULE.adjective_class("形容詞,自立,*,*,形容詞・アウオ段,基本形"),
            "i-adjective",
        )
        self.assertIsNone(
            MODULE.adjective_class("形容詞,自立,*,*,形容詞・アウオ段,連用テ接続")
        )
        self.assertIsNone(MODULE.adjective_class("名詞,一般,*,*,*,*"))

    def test_collects_reading_surface_class_and_lowest_cost(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            (source / "id.def").write_text(
                "1 名詞,形容動詞語幹,*,*,*,*\n"
                "2 形容詞,自立,*,*,形容詞・アウオ段,基本形\n"
                "3 名詞,一般,*,*,*,*\n",
                encoding="utf-8",
            )
            (source / "dictionary00.txt").write_text(
                "べんり\t1\t1\t1200\t便利\n"
                "べんり\t1\t1\t900\t便利\n"
                "すごい\t2\t2\t1000\tすごい\n"
                "がくせい\t3\t3\t500\t学生\n",
                encoding="utf-8",
            )

            self.assertEqual(
                MODULE.collect(source, maximum_cost=7000),
                [
                    ("benri", "便利", "na-adjective-stem", 900),
                    ("sugoi", "すごい", "i-adjective", 1000),
                ],
            )


if __name__ == "__main__":
    unittest.main()
