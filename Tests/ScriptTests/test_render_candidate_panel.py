import struct
import subprocess
import tempfile
import unittest
from pathlib import Path


EXECUTABLE = Path(__file__).parents[2] / ".build/myim.app/Contents/MacOS/myim"


def png_size(path):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise AssertionError("PNGではありません")
    return struct.unpack(">II", data[16:24])


@unittest.skipUnless(
    EXECUTABLE.is_file(),
    "Scripts/build-macos-ime.sh で .build/myim.app を生成してから実行する",
)
class RenderCandidatePanelTests(unittest.TestCase):
    """Needs a logged-in session because the panel is drawn with AppKit"""

    def render(self, *arguments):
        return subprocess.run(
            [str(EXECUTABLE), "--render-candidate-panel", *arguments],
            capture_output=True,
            text=True,
            timeout=60,
        )

    def test_draws_the_candidate_page_as_png(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "kouho.png"

            result = self.render("kouho", str(output))

            self.assertEqual(result.returncode, 0, result.stderr)
            width, height = png_size(output)
            self.assertGreater(width, 0)
            self.assertGreater(height, width)

    def test_selected_row_does_not_change_the_panel_size(self):
        with tempfile.TemporaryDirectory() as directory:
            first = Path(directory) / "first.png"
            third = Path(directory) / "third.png"

            self.assertEqual(self.render("kouho", str(first)).returncode, 0)
            self.assertEqual(
                self.render("kouho", str(third), "2").returncode,
                0,
            )

            self.assertEqual(png_size(first), png_size(third))
            self.assertNotEqual(first.read_bytes(), third.read_bytes())

    def test_rejects_input_without_candidates_or_a_missing_output(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "none.png"

            without_candidates = self.render("", str(output))
            without_output = self.render("kouho")

            self.assertNotEqual(without_candidates.returncode, 0)
            self.assertFalse(output.exists())
            self.assertNotEqual(without_output.returncode, 0)


@unittest.skipUnless(
    EXECUTABLE.is_file(),
    "Scripts/build-macos-ime.sh で .build/myim.app を生成してから実行する",
)
class RenderReadmeDemoTests(unittest.TestCase):
    """Needs a logged-in session because the frames are drawn with AppKit"""

    def render(self, scenario, output):
        return subprocess.run(
            [str(EXECUTABLE), "--render-readme-demo", scenario, str(output)],
            capture_output=True,
            text=True,
            timeout=120,
        )

    def test_renders_the_same_animated_gif_each_time(self):
        with tempfile.TemporaryDirectory() as directory:
            first = Path(directory) / "first.gif"
            second = Path(directory) / "second.gif"

            self.assertEqual(
                self.render("basic-conversion", first).returncode,
                0,
            )
            self.assertEqual(
                self.render("basic-conversion", second).returncode,
                0,
            )

            self.assertIn(first.read_bytes()[:6], (b"GIF87a", b"GIF89a"))
            self.assertIn(b"NETSCAPE2.0", first.read_bytes())
            self.assertEqual(first.read_bytes(), second.read_bytes())

    def test_failure_keeps_the_previous_gif(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "demo.gif"
            output.write_bytes(b"previous")

            result = self.render("unknown-scenario", output)

            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(output.read_bytes(), b"previous")
            self.assertEqual(
                [path.name for path in Path(directory).iterdir()],
                ["demo.gif"],
            )
