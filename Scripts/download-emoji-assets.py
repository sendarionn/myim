#!/usr/bin/env python3

from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import subprocess
import urllib.parse


ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOT = ROOT / "Sources/MyIMEMacOS/Resources/Emoji"
ANDROID_DIR = ASSET_ROOT / "Android"
WINDOWS_DIR = ASSET_ROOT / "Windows"
ANDROID_REVISION = "8998f5dd683424a73e2314a8c1f1e359c19e8742"
WINDOWS_REVISION = "7a40f1a2d064d76e436813edc0f09b6c8cde5da8"
EMOJI_TEST_URL = "https://unicode.org/Public/17.0.0/emoji/emoji-test.txt"


def fetch(url: str) -> bytes:
    return subprocess.check_output([
        "curl", "-fsSL", "--retry", "3", "--max-time", "60", url
    ])


def github_tree(repository: str, revision: str) -> list[dict]:
    url = f"https://api.github.com/repos/{repository}/git/trees/{revision}?recursive=1"
    value = json.loads(fetch(url))
    if value.get("truncated"):
        raise RuntimeError(f"GitHub tree was truncated: {repository}")
    return value["tree"]


def emoji_rows(text: str) -> list[tuple[str, str]]:
    rows = []
    for line in text.splitlines():
        if "; fully-qualified" not in line:
            continue
        left, right = line.split("#", 1)
        scalars = left.split(";", 1)[0].strip().lower().split()
        code = "-".join(value for value in scalars if value != "fe0f")
        emoji = right.strip().split()[0]
        rows.append((code, emoji))
    return rows


def download(item: tuple[str, str, str]) -> None:
    url, platform, code = item
    destination = ASSET_ROOT / platform / f"{code}.png"
    temporary = destination.with_suffix(".download")
    temporary.write_bytes(fetch(url))
    temporary.replace(destination)


def main() -> None:
    ANDROID_DIR.mkdir(parents=True, exist_ok=True)
    WINDOWS_DIR.mkdir(parents=True, exist_ok=True)
    noto_tree = github_tree("googlefonts/noto-emoji", ANDROID_REVISION)
    fluent_tree = github_tree("shuding/fluentui-emoji-unicode", WINDOWS_REVISION)
    noto_codes = {
        item["path"].rsplit("/", 1)[-1][7:-4].replace("_", "-")
        for item in noto_tree
        if item.get("type") == "blob"
        and item["path"].startswith("png/128/emoji_u")
        and item["path"].endswith(".png")
    }
    fluent_names = {
        item["path"].rsplit("/", 1)[-1][:-7]
        for item in fluent_tree
        if item.get("type") == "blob"
        and item["path"].startswith("assets/")
        and item["path"].endswith("_3d.png")
    }
    rows = [
        (code, emoji)
        for code, emoji in emoji_rows(fetch(EMOJI_TEST_URL).decode("utf-8"))
        if code in noto_codes and (code in fluent_names or emoji in fluent_names)
    ]
    expected = {code for code, _ in rows}
    for directory in (ANDROID_DIR, WINDOWS_DIR):
        for path in directory.glob("*.png"):
            if path.stem not in expected:
                path.unlink()

    downloads = []
    for code, emoji in rows:
        android_code = code.replace("-", "_")
        downloads.append((
            "https://raw.githubusercontent.com/googlefonts/noto-emoji/"
            f"{ANDROID_REVISION}/png/128/emoji_u{android_code}.png",
            "Android",
            code,
        ))
        windows_name = code if code in fluent_names else emoji
        quoted_name = urllib.parse.quote(windows_name, safe="")
        downloads.append((
            "https://cdn.jsdelivr.net/gh/shuding/fluentui-emoji-unicode@"
            f"{WINDOWS_REVISION}/assets/{quoted_name}_3d.png",
            "Windows",
            code,
        ))
    with ThreadPoolExecutor(max_workers=16) as executor:
        list(executor.map(download, downloads))

    (ASSET_ROOT / "catalog.tsv").write_text(
        "".join(f"{code}\t{emoji}\n" for code, emoji in rows),
        encoding="utf-8",
    )
    (ASSET_ROOT / "Android-LICENSE.txt").write_bytes(fetch(
        "https://raw.githubusercontent.com/googlefonts/noto-emoji/"
        f"{ANDROID_REVISION}/svg/LICENSE"
    ))
    (ASSET_ROOT / "Windows-LICENSE.txt").write_bytes(fetch(
        "https://raw.githubusercontent.com/shuding/fluentui-emoji-unicode/"
        f"{WINDOWS_REVISION}/LICENSE"
    ))
    print(f"Downloaded {len(rows)} emoji for each platform")


if __name__ == "__main__":
    main()
