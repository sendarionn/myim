#!/usr/bin/env python3

import argparse
import json
import sys
from collections import OrderedDict
from pathlib import Path


TIER_ORDER = {
    "basic": 0,
    "core": 1,
    "general": 2,
}


def split_alternatives(headword: str) -> list[str]:
    normalized = headword.replace("／", "/")
    parts = [part.strip() for part in normalized.split("/") if part.strip()]
    return parts if len(parts) >= 2 else [headword]


def normalize_candidate(value: str) -> str:
    if len(value) <= 1:
        return value
    return value.replace("〜", "").replace("～", "")


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="TKGJEのentries_index.jsonをmyim辞書形式へ変換"
    )
    parser.add_argument("source", type=Path, help="entries_index.json")
    parser.add_argument("output", type=Path, help="出力するdictionary.tsv")
    parser.add_argument(
        "--tiers",
        nargs="+",
        choices=tuple(TIER_ORDER),
        default=list(TIER_ORDER),
        help="取り込む語彙階層",
    )
    return parser.parse_args()


def romaji_from_entry_id(entry_id: str) -> str:
    parts = entry_id.split("_", 1)
    if len(parts) != 2 or not parts[1]:
        raise ValueError(f"ローマ字読みを取得できないID: {entry_id}")
    return parts[1]


def convert(source: Path, output: Path, tiers: set[str]) -> tuple[int, int]:
    with source.open(encoding="utf-8") as source_file:
        document = json.load(source_file)

    entries = document.get("entries")
    if not isinstance(entries, list):
        raise ValueError("entries配列がありません")

    selected_entries = [
        entry
        for entry in entries
        if entry.get("vocabulary_tier") in tiers
    ]
    selected_entries.sort(
        key=lambda entry: (
            TIER_ORDER.get(entry.get("vocabulary_tier"), 99),
            entry.get("id", ""),
        )
    )

    candidates_by_reading: OrderedDict[str, list[str]] = OrderedDict()
    for entry in selected_entries:
        entry_id = entry.get("id")
        headword = entry.get("headword")
        if not isinstance(entry_id, str) or not isinstance(headword, str):
            continue

        reading = romaji_from_entry_id(entry_id)
        candidates = candidates_by_reading.setdefault(reading, [])
        if not headword or "\n" in headword:
            continue
        for candidate in map(normalize_candidate, split_alternatives(headword)):
            if not candidate:
                continue
            if candidate not in candidates:
                candidates.append(candidate)

    lines: list[str] = []
    candidate_count = 0
    for reading, candidates in candidates_by_reading.items():
        if not candidates:
            continue
        lines.append(reading)
        lines.extend(f" {candidate}" for candidate in candidates)
        lines.append("")
        candidate_count += len(candidates)

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines), encoding="utf-8")
    return len(candidates_by_reading), candidate_count


def main() -> int:
    arguments = parse_arguments()
    try:
        reading_count, candidate_count = convert(
            arguments.source,
            arguments.output,
            set(arguments.tiers),
        )
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"変換に失敗しました: {error}", file=sys.stderr)
        return 1

    print(f"登録読み数: {reading_count}")
    print(f"登録候補数: {candidate_count}")
    print(f"保存先: {arguments.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
