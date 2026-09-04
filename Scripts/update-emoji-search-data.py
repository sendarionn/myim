#!/usr/bin/env python3

import json
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]
EMOJI_ROOT = ROOT / "Sources/MyIMEMacOS/Resources/Emoji"
CLDR_VERSION = "48.0.0"
BASE_URL = (
    "https://raw.githubusercontent.com/unicode-org/cldr-json/"
    f"{CLDR_VERSION}/cldr-json"
)


def fetch_json(url: str) -> dict:
    data = subprocess.check_output([
        "curl", "-fsSL", "--retry", "3", "--max-time", "60", url
    ])
    return json.loads(data)


def fetch(url: str) -> bytes:
    return subprocess.check_output([
        "curl", "-fsSL", "--retry", "3", "--max-time", "60", url
    ])


def annotations(language: str) -> dict[str, list[str]]:
    result = {}
    sources = (
        ("cldr-annotations-full", "annotations"),
        ("cldr-annotations-derived-full", "annotationsDerived"),
    )
    for package, root_key in sources:
        value = fetch_json(
            f"{BASE_URL}/{package}/{root_key}/{language}/annotations.json"
        )[root_key]["annotations"]
        for emoji, fields in value.items():
            terms = fields.get("tts", []) + fields.get("default", [])
            result[emoji] = list(dict.fromkeys(terms))
    return result


def clean(values: list[str]) -> str:
    return "|".join(
        value.replace("\t", " ").replace("\n", " ") for value in values
    )


def terms_for(values: dict[str, list[str]], emoji: str) -> list[str]:
    return values.get(emoji, values.get(emoji.replace("\ufe0f", ""), []))


def main() -> None:
    japanese = annotations("ja")
    english = annotations("en")
    rows = []
    for line in (EMOJI_ROOT / "catalog.tsv").read_text(
        encoding="utf-8"
    ).splitlines():
        code, emoji = line.split("\t", 1)
        rows.append(
            f"{code}\t{clean(terms_for(japanese, emoji))}"
            f"\t{clean(terms_for(english, emoji))}\n"
        )
    (EMOJI_ROOT / "search-terms.tsv").write_text(
        "".join(rows),
        encoding="utf-8",
    )
    (EMOJI_ROOT / "CLDR-LICENSE.txt").write_bytes(fetch(
        "https://raw.githubusercontent.com/unicode-org/cldr/"
        f"release-{CLDR_VERSION.split('.', 1)[0]}/LICENSE"
    ))
    print(f"Wrote search terms for {len(rows)} emoji")


if __name__ == "__main__":
    main()
