#!/usr/bin/env python3

from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import sys
from pathlib import Path


START_MARKER = "<!-- README_DEMOS:START -->"
END_MARKER = "<!-- README_DEMOS:END -->"


class DemoConfigurationError(RuntimeError):
    pass


def load_manifest(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("schemaVersion") != 1:
        raise DemoConfigurationError("未対応のデモ定義形式です")

    identifiers: set[str] = set()
    for demo in data.get("demos", []):
        identifier = demo.get("id", "")
        if not identifier or identifier in identifiers:
            raise DemoConfigurationError(f"重複または空の機能IDです: {identifier}")
        identifiers.add(identifier)
        if demo.get("status") not in {"active", "retired", "uncertain"}:
            raise DemoConfigurationError(f"不正な機能状態です: {identifier}")
        image_path = demo.get("image", {}).get("path", "")
        if demo.get("published", False) and not image_path.startswith(
            "https://gyazo.com/"
        ):
            raise DemoConfigurationError(
                f"README画像はGyazo URLを指定してください: {identifier}"
            )
    return data


def published_demos(manifest: dict) -> list[dict]:
    return [
        demo
        for demo in manifest["demos"]
        if demo.get("published", False) and demo.get("status") != "retired"
    ]


def render_demo_section(manifest: dict) -> str:
    demos = published_demos(manifest)
    lines: list[str] = [START_MARKER, ""]

    for demo in demos:
        lines.append(f"- [{demo['title']}](#{demo['anchor']})")

    for demo in demos:
        lines.extend(["", f"## {demo['title']}", ""])
        for paragraph in demo.get("description", []):
            lines.extend([paragraph, ""])
        image = demo.get("image")
        if image:
            lines.append(f"![{image['alt']}]({image['path']})")

    lines.extend(["", END_MARKER])
    return "\n".join(lines)


def replace_managed_section(readme: str, rendered: str) -> str:
    start = readme.find(START_MARKER)
    end = readme.find(END_MARKER)
    if start == -1 or end == -1 or end < start:
        raise DemoConfigurationError("READMEのデモ管理マーカーが見つかりません")
    end += len(END_MARKER)
    return readme[:start] + rendered + readme[end:]


def matching_paths(repository: Path, patterns: list[str]) -> list[Path]:
    matches: set[Path] = set()
    for pattern in patterns:
        matches.update(path for path in repository.glob(pattern) if path.is_file())
    return sorted(matches, key=lambda path: path.relative_to(repository).as_posix())


def source_hash(repository: Path, demo: dict) -> str:
    paths = matching_paths(repository, demo.get("watchPaths", []))
    digest = hashlib.sha256()
    for path in paths:
        relative = path.relative_to(repository).as_posix()
        digest.update(relative.encode("utf-8"))
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def validate_local_images(repository: Path, manifest: dict) -> list[str]:
    missing: list[str] = []
    for demo in published_demos(manifest):
        path = demo.get("image", {}).get("path", "")
        if path and "://" not in path and not (repository / path).is_file():
            missing.append(f"{demo['id']}: {path}")
    return missing


def unmatched_watch_patterns(repository: Path, manifest: dict) -> list[str]:
    unmatched: list[str] = []
    for demo in published_demos(manifest):
        for pattern in demo.get("watchPaths", []):
            if not matching_paths(repository, [pattern]):
                unmatched.append(f"{demo['id']}: {pattern}")
    return unmatched


def atomic_write_text(path: Path, content: str) -> None:
    temporary = path.with_name(f".{path.name}.tmp")
    temporary.write_text(content, encoding="utf-8")
    temporary.replace(path)


def unified_diff(before: str, after: str, path: str) -> str:
    return "".join(
        difflib.unified_diff(
            before.splitlines(keepends=True),
            after.splitlines(keepends=True),
            fromfile=path,
            tofile=path,
        )
    )


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="READMEの機能紹介と動作GIFを同期します"
    )
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    repository = Path(__file__).resolve().parents[1]
    manifest_path = repository / "docs/readme-demos.json"
    readme_path = repository / "README.md"
    manifest = load_manifest(manifest_path)

    manual_review = [
        demo
        for demo in published_demos(manifest)
        if source_hash(repository, demo) != demo.get("verifiedSourceHash", "")
    ]
    print("手動確認対象:")
    if manual_review:
        for demo in manual_review:
            print(f"  {demo['id']}: {demo['title']}")
    else:
        print("  なし")

    before = readme_path.read_text(encoding="utf-8")
    after = replace_managed_section(before, render_demo_section(manifest))
    if arguments.dry_run:
        if before != after:
            print(unified_diff(before, after, "README.md"))
        missing = validate_local_images(repository, manifest)
        unmatched = unmatched_watch_patterns(repository, manifest)
        if missing:
            print("存在しないローカル画像:")
            for value in missing:
                print(f"  {value}")
        if unmatched:
            print("一致するファイルがない監視パターン:")
            for value in unmatched:
                print(f"  {value}")
        if missing or unmatched:
            return 1
        return 0

    missing = validate_local_images(repository, manifest)
    unmatched = unmatched_watch_patterns(repository, manifest)
    if missing:
        raise DemoConfigurationError(
            "存在しないローカル画像があります: " + ", ".join(missing)
        )
    if unmatched:
        raise DemoConfigurationError(
            "一致するファイルがない監視パターンがあります: "
            + ", ".join(unmatched)
        )
    if before != after:
        atomic_write_text(readme_path, after)
        print("README.mdを更新しました")
    else:
        print("README.mdに変更はありません")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except DemoConfigurationError as error:
        print(f"エラー: {error}", file=sys.stderr)
        raise SystemExit(1)
