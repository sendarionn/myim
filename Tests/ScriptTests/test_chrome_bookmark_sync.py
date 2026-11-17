import base64
import hashlib
import json
import os
import re
import struct
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).parents[2]
EXTENSION = ROOT / "ChromeExtension" / "myim-bookmarks"
REGISTRATION = ROOT / "Scripts" / "install-chrome-bookmark-host.sh"


def built_host():
    result = subprocess.run(
        ["swift", "build", "--product", "myim-bookmark-host"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        return None
    path = subprocess.run(
        ["swift", "build", "--show-bin-path"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()
    return Path(path) / "myim-bookmark-host"


class ChromeBookmarkSyncTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.host = built_host()

    def send(self, directory, message):
        payload = json.dumps(message).encode()
        result = subprocess.run(
            [str(self.host)],
            input=struct.pack("<I", len(payload)) + payload,
            capture_output=True,
            env=dict(os.environ, MYIM_BOOKMARK_DIRECTORY=str(directory)),
            check=False,
        )
        length = struct.unpack("<I", result.stdout[:4])[0]
        return json.loads(result.stdout[4:4 + length])

    def message(self, profile_id, name, titles):
        return {
            "type": "replaceBookmarks",
            "profileID": profile_id,
            "profileName": name,
            "bookmarks": [
                {"title": t, "url": f"https://example.com/{t}",
                 "folderPath": "Bar"} for t in titles
            ],
        }

    def test_host_keeps_each_profile_in_its_own_file(self):
        self.assertIsNotNone(self.host)
        with tempfile.TemporaryDirectory() as directory:
            first = self.send(directory, self.message("p1", "Work", ["a", "b"]))
            second = self.send(directory, self.message("p2", "Home", ["c"]))

            self.assertEqual(first, {"ok": True, "count": 2})
            self.assertEqual(second, {"ok": True, "count": 1})
            self.assertEqual(
                sorted(os.listdir(directory)), ["p1.json", "p2.json"]
            )
            saved = json.loads((Path(directory) / "p1.json").read_text())
            self.assertEqual(
                [b["title"] for b in saved["bookmarks"]], ["a", "b"]
            )

    def test_host_refuses_a_profile_id_that_is_a_path(self):
        self.assertIsNotNone(self.host)
        with tempfile.TemporaryDirectory() as directory:
            reply = self.send(directory, self.message("../x", "Work", ["a"]))

            self.assertEqual(reply["ok"], False)
            self.assertEqual(reply["error"], "invalid-profile-id")
            self.assertEqual(os.listdir(directory), [])

    def test_registration_allows_only_the_extension_of_this_repository(self):
        manifest = json.loads((EXTENSION / "manifest.json").read_text())
        digest = hashlib.sha256(base64.b64decode(manifest["key"])).hexdigest()
        extension_id = "".join(
            chr(ord("a") + int(c, 16)) for c in digest[:32]
        )
        script = REGISTRATION.read_text()

        self.assertIn(f'extension_id="{extension_id}"', script)
        self.assertIn('"allowed_origins": ["chrome-extension://$extension_id/"]',
                      script)
        self.assertIn("--system", script)

    def test_extension_sends_bookmarks_only_to_the_native_host(self):
        manifest = json.loads((EXTENSION / "manifest.json").read_text())
        background = (EXTENSION / "background.js").read_text()

        self.assertEqual(manifest["manifest_version"], 3)
        self.assertEqual(
            sorted(manifest["permissions"]),
            ["bookmarks", "nativeMessaging", "storage"],
        )
        self.assertNotIn("host_permissions", manifest)
        self.assertNotRegex(background, r"\bfetch\(|XMLHttpRequest")
        for event in ["onCreated", "onChanged", "onMoved", "onRemoved"]:
            self.assertIn(f"chrome.bookmarks.{event}", background)

    def test_no_code_reads_chrome_profile_files(self):
        for path in (ROOT / "Sources").rglob("*.swift"):
            source = path.read_text(encoding="utf-8")
            with self.subTest(file=path.name):
                self.assertIsNone(
                    re.search(r'"AccountBookmarks"|ChromeBookmarkReader', source)
                )


if __name__ == "__main__":
    unittest.main()
