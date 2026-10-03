import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[2] / "Scripts" / "generate-mozc-person-name-hints.py"
SPEC = importlib.util.spec_from_file_location("generate_mozc_person_name_hints", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class GenerateMozcPersonNameHintsTests(unittest.TestCase):
    def make_source(self, directory: Path, lines: str) -> Path:
        (directory / "id.def").write_text(
            "1 名詞,一般,*,*,*,*,*\n"
            "2 名詞,固有名詞,人名,姓,*,*,*\n",
            encoding="utf-8",
        )
        (directory / "dictionary00.txt").write_text(lines, encoding="utf-8")
        return directory

    def hints(self, lines: str) -> list[tuple[str, str]]:
        with tempfile.TemporaryDirectory() as directory:
            source = self.make_source(Path(directory), lines)
            costs, names = MODULE.collect(source, maximum_cost=7000)
            return MODULE.particle_shadowed_names(costs, names)

    def test_marks_a_person_name_when_the_stem_is_cheaper(self):
        self.assertEqual(
            self.hints(
                "つぎの\t2\t2\t5458\t調\n"
                "つぎ\t1\t1\t2021\t次\n"
            ),
            [("tsugino", "調")],
        )

    def test_keeps_a_person_name_cheaper_than_the_stem(self):
        self.assertEqual(
            self.hints(
                "さの\t2\t2\t3000\t佐野\n"
                "さ\t1\t1\t5000\t差\n"
                "さ\t1\t1\t5000\t差\n"
            ),
            [],
        )

    def test_ignores_general_nouns_and_short_stems(self):
        self.assertEqual(
            self.hints(
                "つぎの\t1\t1\t5458\t次野\n"
                "つぎ\t1\t1\t2021\t次\n"
                "おの\t2\t2\t6000\t小埜\n"
                "お\t1\t1\t1000\t尾\n"
            ),
            [],
        )

    def test_does_not_mark_a_candidate_that_is_also_a_general_word(self):
        self.assertEqual(
            self.hints(
                "つぎの\t2\t2\t5458\t調\n"
                "つぎの\t1\t1\t5600\t調\n"
                "つぎ\t1\t1\t2021\t次\n"
            ),
            [],
        )


if __name__ == "__main__":
    unittest.main()
