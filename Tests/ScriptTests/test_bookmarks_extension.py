import json
import subprocess
import unittest
from pathlib import Path


SCRIPT = (
    Path(__file__).parents[2]
    / "Sources"
    / "MyIMEMacOS"
    / "Resources"
    / "Extensions"
    / "bookmarks.js"
)


class BookmarksExtensionTests(unittest.TestCase):
    def formats(self, title, url, folder_path=""):
        runner = f"""
const fs = require("fs")
eval(fs.readFileSync({json.dumps(str(SCRIPT))}, "utf8"))
process.stdout.write(JSON.stringify(bookmarkFormats({{
  input: "bookmarks",
  parameters: {{
    title: {json.dumps(title)},
    url: {json.dumps(url)},
    folderPath: {json.dumps(folder_path)}
  }}
}})))
"""
        completed = subprocess.run(
            ["node", "-e", runner],
            check=True,
            capture_output=True,
            text=True,
        )
        return json.loads(completed.stdout)

    def test_returns_url_linked_title_and_markdown(self):
        self.assertEqual(
            self.formats("Swift", "https://swift.org", "Development"),
            [
                {"id": "url", "label": "URL", "text": "https://swift.org"},
                {
                    "id": "linked-title",
                    "label": "リンク付きタイトル",
                    "text": "Swift",
                    "linkURL": "https://swift.org",
                },
                {
                    "id": "markdown",
                    "label": "Markdownリンク",
                    "text": "[Swift](https://swift.org)",
                },
            ],
        )

    def test_escapes_markdown_label_and_rejects_missing_url(self):
        formats = self.formats("[Swift]", "https://swift.org")
        self.assertEqual(
            formats[2]["text"], "[\\[Swift\\]](https://swift.org)"
        )
        self.assertEqual(self.formats("Swift", ""), [])


if __name__ == "__main__":
    unittest.main()
