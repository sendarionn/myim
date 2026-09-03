from pathlib import Path
import unittest


class EmojiAssetsTests(unittest.TestCase):
    def test_catalog_and_platform_assets_match(self):
        root = Path(__file__).resolve().parents[2]
        emoji_root = root / "Sources/MyIMEMacOS/Resources/Emoji"
        rows = [
            line.split("\t", 1)
            for line in (emoji_root / "catalog.tsv").read_text(
                encoding="utf-8"
            ).splitlines()
            if line
        ]
        codes = [columns[0] for columns in rows]

        self.assertEqual(2980, len(rows))
        self.assertEqual(len(codes), len(set(codes)))
        for platform in ("Android", "Windows"):
            files = {path.stem for path in (emoji_root / platform).glob("*.png")}
            self.assertEqual(set(codes), files)

    def test_assets_are_normalized_png_files(self):
        root = Path(__file__).resolve().parents[2]
        emoji_root = root / "Sources/MyIMEMacOS/Resources/Emoji"
        png_signature = b"\x89PNG\r\n\x1a\n"
        for platform in ("Android", "Windows"):
            for path in (emoji_root / platform).glob("*.png"):
                data = path.read_bytes()
                self.assertTrue(data.startswith(png_signature), path)
                self.assertEqual((96).to_bytes(4, "big"), data[16:20], path)
                self.assertEqual((96).to_bytes(4, "big"), data[20:24], path)


if __name__ == "__main__":
    unittest.main()
