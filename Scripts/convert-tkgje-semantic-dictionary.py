#!/usr/bin/env python3

import argparse
import json
import re
import sys
from pathlib import Path


TIER_ORDER = {"basic": 0, "core": 1, "general": 2}
FURIGANA_PATTERN = re.compile(r"\{([^|{}]+)\|[^{}]+\}")


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="TKGJEの個別項目からmyim意味検索用JSONLを生成"
    )
    parser.add_argument("repository", type=Path, help="TKGJEリポジトリのルート")
    parser.add_argument("output", type=Path, help="出力するsemantic-dictionary.jsonl")
    parser.add_argument(
        "--tiers",
        nargs="+",
        choices=tuple(TIER_ORDER),
        default=list(TIER_ORDER),
        help="取り込む語彙階層",
    )
    return parser.parse_args()


def plain_headword(value: str) -> str:
    return FURIGANA_PATTERN.sub(lambda match: match.group(1), value)


def entry_path(repository: Path, entry_id: str) -> Path:
    number_text = entry_id.split("_", 1)[0]
    if len(number_text) != 5 or not number_text.isdigit():
        raise ValueError(f"項目IDの形式が不正: {entry_id}")
    directory = f"{int(number_text) // 500 * 500:05d}"
    return repository / "entries" / directory / f"{entry_id}.json"


def unique_strings(values: list[object]) -> list[str]:
    result: list[str] = []
    for value in values:
        if not isinstance(value, str):
            continue
        normalized = " ".join(value.split())
        if normalized and normalized not in result:
            result.append(normalized)
    return result


def semantic_entry(document: dict, entry_id: str, vocabulary_tier: str) -> dict | None:
    headword = document.get("headword")
    reading = entry_id.split("_", 1)[1] if "_" in entry_id else ""
    if not isinstance(headword, str) or not headword or not reading:
        return None
    definitions = document.get("definitions")
    definitions = definitions if isinstance(definitions, list) else []
    glosses = unique_strings(
        [document.get("gloss")]
        + [definition.get("gloss") for definition in definitions if isinstance(definition, dict)]
    )
    explanations = unique_strings(
        [definition.get("explanation") for definition in definitions if isinstance(definition, dict)]
    )
    if not glosses and not explanations:
        return None
    result = {
        "id": entry_id,
        "headword": plain_headword(headword),
        "reading": reading,
        "glosses": glosses,
        "explanations": explanations,
        "source": "TKGJE",
        "vocabularyTier": vocabulary_tier,
    }
    part_of_speech = document.get("part_of_speech")
    if isinstance(part_of_speech, str) and part_of_speech:
        result["partOfSpeech"] = part_of_speech
    return result


def convert(repository: Path, output: Path, tiers: set[str]) -> tuple[int, int]:
    index_path = repository / "entries_index.json"
    with index_path.open(encoding="utf-8") as source_file:
        index = json.load(source_file)
    entries = index.get("entries")
    if not isinstance(entries, list):
        raise ValueError("entries_index.jsonにentries配列がありません")
    selected = sorted(
        (
            item for item in entries
            if isinstance(item, dict) and item.get("vocabulary_tier") in tiers
        ),
        key=lambda item: (
            TIER_ORDER.get(item.get("vocabulary_tier"), 99),
            item.get("id", ""),
        ),
    )
    output_entries: list[dict] = []
    missing_count = 0
    for item in selected:
        entry_id = item.get("id")
        if not isinstance(entry_id, str):
            continue
        path = entry_path(repository, entry_id)
        if not path.is_file():
            missing_count += 1
            continue
        with path.open(encoding="utf-8") as entry_file:
            document = json.load(entry_file)
        entry = semantic_entry(document, entry_id, item["vocabulary_tier"])
        if entry is not None:
            output_entries.append(entry)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8") as output_file:
        for entry in output_entries:
            output_file.write(json.dumps(entry, ensure_ascii=False, separators=(",", ":")))
            output_file.write("\n")
    return len(output_entries), missing_count


def main() -> int:
    arguments = parse_arguments()
    try:
        entry_count, missing_count = convert(
            arguments.repository,
            arguments.output,
            set(arguments.tiers),
        )
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"変換に失敗しました: {error}", file=sys.stderr)
        return 1
    print(f"登録項目数: {entry_count}")
    print(f"未検出項目数: {missing_count}")
    print(f"保存先: {arguments.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
