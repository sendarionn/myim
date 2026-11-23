import unittest
from pathlib import Path


SOURCES = Path(__file__).parents[2] / "Sources" / "MyIMEMacOS"


class ReconversionShortcutTests(unittest.TestCase):
    """Reconversion starts with its own shortcut, never with Tab, which
    applications also use to move focus"""

    def setUp(self):
        self.controller = (SOURCES / "InputController.swift").read_text(
            encoding="utf-8"
        )

    def body(self, signature):
        start = self.controller.index(signature)
        return self.controller[start:self.controller.index("\n    }\n", start)]

    def test_tab_does_not_reconvert(self):
        self.assertNotIn("beginReconversionIfPossible",
                         self.body("private func handleTab("))

    def test_option_r_reconverts_and_is_taken(self):
        shortcuts = (SOURCES / "MyIMFeatureShortcut.swift").read_text(
            encoding="utf-8"
        )
        self.assertIn(
            'case .reconversion: MyIMShortcut(modifiers: [.option], key: "r")',
            shortcuts,
        )
        start = self.controller.index(
            "if MyIMFeatureShortcut.reconversion.shortcut.matches(event) {"
        )
        branch = self.controller[start:start + 300]
        self.assertIn("beginReconversionIfPossible(client: sender)", branch)
        self.assertIn("return true", branch)


if __name__ == "__main__":
    unittest.main()
