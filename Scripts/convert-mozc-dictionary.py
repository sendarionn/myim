#!/usr/bin/env python3

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Mozc OSS辞書をmyimのかな漢字変換辞書へ変換"
    )
    parser.add_argument("source", type=Path, help="Mozc dictionary_ossディレクトリ")
    parser.add_argument("output", type=Path, help="出力するime-dictionary.txt")
    parser.add_argument("--metadata", type=Path, help="生成情報JSONの出力先")
    parser.add_argument("--source-revision", default="unknown")
    parser.add_argument("--maximum-candidates", type=int, default=32)
    parser.add_argument(
        "--maximum-cost",
        type=int,
        default=7000,
        help="Mozc候補コストの上限  小さい候補ほど優先",
    )
    return parser.parse_args()


def is_kana_reading(value: str) -> bool:
    return bool(value) and all(
        "ぁ" <= character <= "ゖ" or character in "ーゔ"
        for character in value
    )


def normalize_candidate(value: str) -> str:
    if len(value) <= 1:
        return value
    return value.replace("〜", "").replace("～", "")


def convert(
    source: Path,
    maximum_candidates: int,
    maximum_cost: int = 7000,
) -> dict[str, list[str]]:
    if maximum_candidates < 1:
        raise ValueError("候補上限は1以上で指定してください")
    source_files = sorted(source.glob("dictionary[0-9][0-9].txt"))
    if not source_files:
        raise ValueError("Mozc辞書ファイルがありません")

    values: dict[str, dict[str, int]] = defaultdict(dict)
    for source_file in source_files:
        with source_file.open(encoding="utf-8") as stream:
            for line_number, raw_line in enumerate(stream, 1):
                columns = raw_line.rstrip("\n").split("\t")
                if len(columns) < 5:
                    raise ValueError(f"{source_file.name}:{line_number} の列数が不正です")
                reading, _, _, cost_text, candidate = columns[:5]
                candidate = normalize_candidate(candidate)
                if not is_kana_reading(reading) or not candidate or "\n" in candidate:
                    continue
                if candidate == reading:
                    continue
                try:
                    cost = int(cost_text)
                except ValueError as error:
                    raise ValueError(
                        f"{source_file.name}:{line_number} のコストが不正です"
                    ) from error
                if cost > maximum_cost:
                    continue
                previous = values[reading].get(candidate)
                if previous is None or cost < previous:
                    values[reading][candidate] = cost

    result: dict[str, list[str]] = {}
    for reading in sorted(values):
        ranked = sorted(values[reading].items(), key=lambda item: (item[1], item[0]))
        result[reading] = [candidate for candidate, _ in ranked[:maximum_candidates]]
    return result


def write_dictionary(entries: dict[str, list[str]], output: Path) -> int:
    lines: list[str] = []
    candidate_count = 0
    for reading, candidates in entries.items():
        if not candidates:
            continue
        lines.append(reading)
        lines.extend(f" {candidate}" for candidate in candidates)
        lines.append("")
        candidate_count += len(candidates)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines), encoding="utf-8")
    return candidate_count


def main() -> int:
    arguments = parse_arguments()
    try:
        entries = convert(
            arguments.source,
            arguments.maximum_candidates,
            arguments.maximum_cost,
        )
        candidate_count = write_dictionary(entries, arguments.output)
        if arguments.metadata:
            metadata = {
                "source": "google/mozc src/data/dictionary_oss",
                "sourceRevision": arguments.source_revision,
                "maximumCandidatesPerReading": arguments.maximum_candidates,
                "maximumCost": arguments.maximum_cost,
                "readingCount": len(entries),
                "candidateCount": candidate_count,
            }
            arguments.metadata.parent.mkdir(parents=True, exist_ok=True)
            arguments.metadata.write_text(
                json.dumps(metadata, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
    except (OSError, ValueError) as error:
        print(f"変換に失敗しました: {error}", file=sys.stderr)
        return 1

    print(f"登録読み数: {len(entries)}")
    print(f"登録候補数: {candidate_count}")
    print(f"保存先: {arguments.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
