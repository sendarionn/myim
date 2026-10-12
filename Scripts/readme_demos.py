#!/usr/bin/env python3

from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import shutil
import subprocess
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


def write_manifest(path: Path, manifest: dict) -> None:
    atomic_write_text(
        path, json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"
    )


def mark_recording_verified(demo: dict, verified_hash: str) -> None:
    demo["verifiedSourceHash"] = verified_hash


def atomic_write_text(path: Path, content: str) -> None:
    temporary = path.with_name(f".{path.name}.tmp")
    temporary.write_text(content, encoding="utf-8")
    temporary.replace(path)


def record_demo(repository: Path, demo: dict) -> tuple[Path, Path, str]:
    recording = demo.get("recording")
    if not recording:
        raise DemoConfigurationError(f"{demo['id']}には自動録画シナリオがありません")

    output = repository / recording["output"]
    output.parent.mkdir(parents=True, exist_ok=True)
    staging = output.with_name(f".{output.name}.recording")
    error_report = Path(str(staging) + ".error.txt")
    staging.unlink(missing_ok=True)
    error_report.unlink(missing_ok=True)
    tools_directory = repository / ".build/readme-demo-tools"
    tools_directory.mkdir(parents=True, exist_ok=True)
    recorder_source = repository / "Scripts/record-readme-demo.swift"
    recorder_plist = repository / "Scripts/ReadmeDemoRecorder-Info.plist"
    recorder_bundle = tools_directory / "myim README demo recorder.app"
    recorder_contents = recorder_bundle / "Contents"
    recorder_macos = recorder_contents / "MacOS"
    recorder = recorder_macos / "myim-readme-demo-recorder"
    compile_command = [
        "/usr/bin/xcrun",
        "swiftc",
        "-O",
        str(recorder_source),
        "-o",
        str(recorder),
    ]
    newest_source = max(
        recorder_source.stat().st_mtime_ns,
        recorder_plist.stat().st_mtime_ns,
    )
    if not recorder.is_file() or recorder.stat().st_mtime_ns < newest_source:
        legacy_bundle = tools_directory / "readme-demo-recorder.app"
        if legacy_bundle.exists():
            shutil.rmtree(legacy_bundle)
        if recorder_bundle.exists():
            shutil.rmtree(recorder_bundle)
        recorder_macos.mkdir(parents=True)
        subprocess.run(compile_command, cwd=repository, check=True)
        shutil.copy2(recorder_plist, recorder_contents / "Info.plist")
        subprocess.run(
            [
                "/usr/bin/codesign",
                "--force",
                "--sign",
                "-",
                str(recorder_bundle),
            ],
            cwd=repository,
            check=True,
        )
    command = [
        "/usr/bin/open",
        "-W",
        "-n",
        str(recorder_bundle),
        "--args",
        recording["scenario"],
        str(staging),
        recording["expectedText"],
    ]
    try:
        try:
            subprocess.run(command, cwd=repository, check=True)
        except subprocess.CalledProcessError as error:
            detail = (
                error_report.read_text(encoding="utf-8").strip()
                if error_report.is_file()
                else str(error)
            )
            raise DemoConfigurationError(detail) from error
        if not staging.is_file() or staging.stat().st_size == 0:
            detail = (
                error_report.read_text(encoding="utf-8").strip()
                if error_report.is_file()
                else "録画アプリが結果を返しませんでした"
            )
            raise DemoConfigurationError(
                f"録画処理がGIFを生成しませんでした: {detail}"
            )
    except Exception:
        staging.unlink(missing_ok=True)
        raise
    finally:
        error_report.unlink(missing_ok=True)
    return staging, output, source_hash(repository, demo)


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
    parser.add_argument("demo_ids", nargs="*")
    parser.add_argument("--all", action="store_true", dest="record_all")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--readme-only", action="store_true")
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    repository = Path(__file__).resolve().parents[1]
    manifest_path = repository / "docs/readme-demos.json"
    readme_path = repository / "README.md"
    manifest = load_manifest(manifest_path)
    by_identifier = {demo["id"]: demo for demo in manifest["demos"]}

    unknown = sorted(set(arguments.demo_ids) - set(by_identifier))
    if unknown:
        raise DemoConfigurationError(
            "未定義の機能IDです: " + ", ".join(unknown)
        )

    changed: list[dict] = []
    manual_review: list[dict] = []
    for demo in published_demos(manifest):
        current_hash = source_hash(repository, demo)
        if current_hash == demo.get("verifiedSourceHash", ""):
            continue
        if demo.get("recording"):
            changed.append(demo)
        else:
            manual_review.append(demo)

    if arguments.demo_ids:
        requested = [by_identifier[identifier] for identifier in arguments.demo_ids]
    elif arguments.record_all:
        requested = [demo for demo in published_demos(manifest) if demo.get("recording")]
    else:
        requested = changed

    print("自動録画対象:")
    if requested:
        for demo in requested:
            print(f"  {demo['id']}: {demo['title']}")
    else:
        print("  なし")

    print("手動確認対象:")
    if manual_review:
        for demo in manual_review:
            print(f"  {demo['id']}: 自動録画シナリオ未実装")
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

    if not arguments.readme_only:
        staged_recordings: list[tuple[dict, Path, Path, str]] = []
        try:
            for demo in requested:
                staging, output, verified_hash = record_demo(repository, demo)
                staged_recordings.append(
                    (demo, staging, output, verified_hash)
                )
        except Exception:
            for _, staging, _, _ in staged_recordings:
                staging.unlink(missing_ok=True)
            raise
        for demo, staging, output, verified_hash in staged_recordings:
            staging.replace(output)
            mark_recording_verified(demo, verified_hash)
        if requested:
            write_manifest(manifest_path, manifest)

    after = replace_managed_section(before, render_demo_section(manifest))
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
    except (DemoConfigurationError, subprocess.CalledProcessError) as error:
        print(f"エラー: {error}", file=sys.stderr)
        raise SystemExit(1)
