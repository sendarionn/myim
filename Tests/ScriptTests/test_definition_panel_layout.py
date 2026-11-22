import unittest
from pathlib import Path


SOURCE = (
    Path(__file__).parents[2]
    / "Sources" / "MyIMEMacOS" / "ExternalInformationWindowController.swift"
)


class DefinitionPanelLayoutTests(unittest.TestCase):
    """The definition text view was created with no size and kept a zero
    width inside its scroll view, so the definitions it held were never
    laid out and the panel stayed empty"""

    def setUp(self):
        self.source = SOURCE.read_text(encoding="utf-8")

    def test_text_view_follows_the_scroll_view_width(self):
        for setting in [
            "definitionTextView.isVerticallyResizable = true",
            "definitionTextView.isHorizontallyResizable = false",
            "definitionTextView.autoresizingMask = [.width]",
            "definitionTextView.textContainer?.widthTracksTextView = true",
        ]:
            with self.subTest(setting=setting):
                self.assertIn(setting, self.source)
        self.assertLess(
            self.source.index("definitionTextView.autoresizingMask"),
            self.source.index("scrollView.documentView = definitionTextView"),
        )

    def test_text_view_takes_the_panel_width_when_placed(self):
        start = self.source.index("private func positionDefinitionPanel(")
        body = self.source[start:self.source.index("\n    }\n", start)]
        self.assertLess(
            body.index("definitionPanel.setContentSize(panelSize)"),
            body.index("width: scrollView.contentSize.width"),
        )


if __name__ == "__main__":
    unittest.main()
