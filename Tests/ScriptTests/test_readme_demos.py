import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest import mock


MODULE_PATH = Path(__file__).parents[2] / "Scripts" / "readme_demos.py"
SPEC = importlib.util.spec_from_file_location("readme_demos", MODULE_PATH)
readme_demos = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(readme_demos)


class ReadmeDemoTests(unittest.TestCase):
    def demo(self, **overrides):
        value = {
            "id": "input",
            "title": "入力",
            "anchor": "入力",
            "published": True,
            "status": "active",
            "description": ["入力できます"],
            "image": {"alt": "入力", "path": "docs/demos/input.gif"},
            "watchPaths": ["Sources/*.swift"],
            "verifiedSourceHash": "",
        }
        value.update(overrides)
        return value

    def test_render_uses_manifest_as_single_source(self):
        rendered = readme_demos.render_demo_section(
            {"demos": [self.demo()]}
        )
        self.assertIn("- [入力](#入力)", rendered)
        self.assertIn("## 入力", rendered)
        self.assertIn("![入力](docs/demos/input.gif)", rendered)

    def test_manifest_rejects_non_gyazo_readme_image(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manifest.json"
            path.write_text(
                '{"schemaVersion":1,"demos":['
                '{"id":"input","published":true,"status":"active",'
                '"image":{"path":"docs/demos/input.gif"}}]}',
                encoding="utf-8",
            )
            with self.assertRaises(readme_demos.DemoConfigurationError):
                readme_demos.load_manifest(path)

    def test_retired_demo_is_not_rendered(self):
        rendered = readme_demos.render_demo_section(
            {"demos": [self.demo(status="retired")]}
        )
        self.assertNotIn("## 入力", rendered)

    def test_replacement_preserves_unmanaged_text(self):
        original = "before\n<!-- README_DEMOS:START -->\nold\n<!-- README_DEMOS:END -->\nafter\n"
        rendered = readme_demos.render_demo_section(
            {"demos": [self.demo()]}
        )
        updated = readme_demos.replace_managed_section(original, rendered)
        self.assertTrue(updated.startswith("before\n"))
        self.assertTrue(updated.endswith("\nafter\n"))
        self.assertNotIn("\nold\n", updated)

    def test_source_hash_changes_only_when_watched_file_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            sources = root / "Sources"
            sources.mkdir()
            watched = sources / "Input.swift"
            unrelated = root / "README.md"
            watched.write_text("one", encoding="utf-8")
            unrelated.write_text("before", encoding="utf-8")
            demo = self.demo()
            first = readme_demos.source_hash(root, demo)
            unrelated.write_text("after", encoding="utf-8")
            self.assertEqual(first, readme_demos.source_hash(root, demo))
            watched.write_text("two", encoding="utf-8")
            self.assertNotEqual(first, readme_demos.source_hash(root, demo))

    def test_missing_local_image_is_reported_but_remote_image_is_not(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest = {"demos": [self.demo()]}
            self.assertEqual(
                ["input: docs/demos/input.gif"],
                readme_demos.validate_local_images(root, manifest),
            )
            manifest["demos"][0]["image"]["path"] = (
                "https://example.com/input.gif"
            )
            self.assertEqual(
                [], readme_demos.validate_local_images(root, manifest)
            )

    def test_recording_without_output_does_not_replace_verified_image(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / "Scripts"
            scripts.mkdir()
            (scripts / "record-readme-demo.swift").write_text(
                "// recorder", encoding="utf-8"
            )
            (scripts / "ReadmeDemoRecorder-Info.plist").write_text(
                "<plist/>", encoding="utf-8"
            )
            demo = self.demo(
                image={"alt": "入力", "path": "https://example.com/input.gif"},
                recording={
                    "scenario": "input",
                    "output": "docs/demos/input.gif",
                    "expectedText": "入力",
                },
            )
            with mock.patch.object(readme_demos.subprocess, "run"):
                with self.assertRaises(readme_demos.DemoConfigurationError):
                    readme_demos.record_demo(root, demo)
            self.assertEqual(
                "https://example.com/input.gif", demo["image"]["path"]
            )
            self.assertEqual("", demo["verifiedSourceHash"])
            self.assertFalse((root / "docs/demos/.input.gif.recording").exists())

    def test_successful_recording_verification_keeps_gyazo_image(self):
        demo = self.demo(
            image={
                "alt": "入力",
                "path": "https://gyazo.com/example.gif",
            }
        )
        readme_demos.mark_recording_verified(demo, "verified-hash")
        self.assertEqual(
            "https://gyazo.com/example.gif", demo["image"]["path"]
        )
        self.assertEqual("verified-hash", demo["verifiedSourceHash"])

    def test_unmatched_watch_pattern_is_reported(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest = {"demos": [self.demo()]}
            self.assertEqual(
                ["input: Sources/*.swift"],
                readme_demos.unmatched_watch_patterns(root, manifest),
            )


if __name__ == "__main__":
    unittest.main()
