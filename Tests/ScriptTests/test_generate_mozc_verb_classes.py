import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[2] / "Scripts" / "generate-mozc-verb-classes.py"
SPEC = importlib.util.spec_from_file_location("generate_mozc_verb_classes", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class GenerateMozcVerbClassesTests(unittest.TestCase):
    def collect(self, lines: str) -> list[tuple[str, str, str, int]]:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            (source / "id.def").write_text(
                "1 動詞,自立,*,*,五段動詞,基本形,*\n"
                "2 動詞,自立,*,*,一段,基本形,*\n"
                "3 動詞,自立,*,*,サ変,基本形,*\n"
                "4 動詞,自立,*,*,カ変・来ル,基本形,*\n"
                "5 動詞,自立,*,*,五段・カ行促音便,基本形,行く\n"
                "6 動詞,自立,*,*,五段動詞,連用形,*\n"
                "7 動詞,非自立,*,*,一段,基本形,*\n"
                "8 名詞,一般,*,*,*,*,*\n",
                encoding="utf-8",
            )
            (source / "dictionary00.txt").write_text(lines, encoding="utf-8")
            return MODULE.collect(source, maximum_cost=7000)

    def test_keeps_base_forms_with_their_class(self):
        self.assertEqual(
            self.collect(
                "しる\t1\t1\t3000\t知る\n"
                "みる\t2\t2\t2000\t見る\n"
                "あいする\t3\t3\t4000\t愛する\n"
                "にんずる\t3\t3\t4000\t任ずる\n"
                "くる\t4\t4\t1000\t来る\n"
                "いく\t5\t5\t100\t行く\n"
            ),
            [
                ("aisuru", "愛する", "suru", 4000),
                ("iku", "行く", "godan-iku", 100),
                ("kuru", "来る", "kuru", 1000),
                ("miru", "見る", "ichidan", 2000),
                ("ninzuru", "任ずる", "zuru", 4000),
                ("shiru", "知る", "godan", 3000),
            ],
        )

    def test_skips_other_forms_dependent_verbs_and_mismatched_surfaces(self):
        self.assertEqual(
            self.collect(
                "しり\t6\t6\t2000\t知り\n"
                "いる\t7\t7\t1000\tいる\n"
                "しる\t8\t8\t1000\t汁\n"
                "よる\t1\t1\t3000\tよる厳選\n"
                "しる\t1\t1\t8000\t痴る\n"
            ),
            [],
        )


if __name__ == "__main__":
    unittest.main()
