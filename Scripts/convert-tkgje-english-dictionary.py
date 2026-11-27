#!/usr/bin/env python3
"""TKGJEのentries_index.jsonから、日本語の読みで英訳を引く辞書を作る

辞書にある英訳（gloss）だけを使い、推測で訳語を作らない
"""

import argparse
import json
import re
import sys
from collections import OrderedDict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from dictionary_key import kana_to_dictionary_key


TIER_ORDER = {
    "basic": 0,
    "core": 1,
    "general": 2,
}

MAXIMUM_CANDIDATES = 3
MAXIMUM_WORDS = 3
MAXIMUM_LENGTH = 24
ENGLISH_PATTERN = re.compile(r"^[A-Za-z][A-Za-z' -]*[A-Za-z]$|^[A-Za-z]$")


def split_gloss(gloss: str) -> list[str]:
    """カンマとセミコロンで分ける。括弧の中の区切りでは分けない"""
    parts: list[str] = []
    depth = 0
    current = ""
    for character in gloss:
        if character in "([":
            depth += 1
        elif character in ")]":
            depth = max(depth - 1, 0)
        if character in ",;" and depth == 0:
            parts.append(current)
            current = ""
            continue
        current += character
    parts.append(current)
    return [part.strip() for part in parts if part.strip()]


def english_candidate(part: str) -> str | None:
    """候補にできる短い英語表現だけを返す。動詞のtoは外す"""
    if "(" in part or ")" in part or "[" in part or "/" in part:
        return None
    value = " ".join(part.split())
    if value.lower().startswith("to "):
        value = value[3:]
    if not ENGLISH_PATTERN.match(value):
        return None
    if len(value) > MAXIMUM_LENGTH or len(value.split()) > MAXIMUM_WORDS:
        return None
    if "..." in value:
        return None
    return value


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="TKGJEのentries_index.jsonから日本語→英語の候補辞書を作る"
    )
    parser.add_argument("source", type=Path, help="entries_index.json")
    parser.add_argument("output", type=Path, help="出力するTSV（読み\\t英訳）")
    return parser.parse_args()


def convert(source: Path, output: Path) -> tuple[int, int]:
    with source.open(encoding="utf-8") as source_file:
        document = json.load(source_file)

    entries = document.get("entries")
    if not isinstance(entries, list):
        raise ValueError("entries配列がありません")

    selected = [
        entry
        for entry in entries
        if entry.get("vocabulary_tier") in TIER_ORDER
        and isinstance(entry.get("reading"), str)
        and isinstance(entry.get("gloss"), str)
        and entry.get("reading")
    ]
    selected.sort(
        key=lambda entry: (
            TIER_ORDER[entry["vocabulary_tier"]],
            entry.get("id", ""),
        )
    )

    # 読みごとに、見出し語ごとの訳語を優先順に集める
    glosses_by_reading: OrderedDict[str, list[list[str]]] = OrderedDict()
    for entry in selected:
        reading = kana_to_dictionary_key(entry["reading"])
        if not reading:
            continue
        words = [
            candidate
            for candidate in map(english_candidate, split_gloss(entry["gloss"]))
            if candidate
        ]
        if words:
            glosses_by_reading.setdefault(reading, []).append(words)

    # 同じ読みの別の語（橋・箸・端）が埋もれないよう、各語の最初の訳語から
    # 順に取る
    candidates_by_reading: OrderedDict[str, list[str]] = OrderedDict()
    for reading, glosses in glosses_by_reading.items():
        candidates: list[str] = []
        for position in range(max(len(words) for words in glosses)):
            for words in glosses:
                if len(candidates) >= MAXIMUM_CANDIDATES:
                    break
                if position < len(words) and words[position] not in candidates:
                    candidates.append(words[position])
        candidates_by_reading[reading] = candidates

    lines = [
        f"{reading}\t{candidate}"
        for reading, candidates in sorted(candidates_by_reading.items())
        for candidate in candidates
    ]
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    readings = sum(1 for candidates in candidates_by_reading.values() if candidates)
    return readings, len(lines)


def main() -> int:
    arguments = parse_arguments()
    try:
        reading_count, candidate_count = convert(arguments.source, arguments.output)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"変換に失敗しました: {error}", file=sys.stderr)
        return 1
    print(f"登録読み数: {reading_count}")
    print(f"登録候補数: {candidate_count}")
    print(f"保存先: {arguments.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
