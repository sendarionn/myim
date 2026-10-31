#!/usr/bin/env python3
"""Mozcの形容動詞語幹と形容詞基本形を読み・表記・種類・コストで出力する"""

import argparse
import importlib.util
import sys
from pathlib import Path


CONVERTER_PATH = Path(__file__).with_name("convert-mozc-dictionary.py")
CONVERTER_SPEC = importlib.util.spec_from_file_location(
    "convert_mozc_dictionary", CONVERTER_PATH
)
CONVERTER = importlib.util.module_from_spec(CONVERTER_SPEC)
CONVERTER_SPEC.loader.exec_module(CONVERTER)


def adjective_class(part_of_speech: str) -> str | None:
    fields = part_of_speech.split(",")
    if len(fields) < 6:
        return None
    if fields[0] == "名詞" and fields[1] == "形容動詞語幹":
        return "na-adjective-stem"
    if fields[0] == "形容詞" and fields[5] == "基本形":
        return "i-adjective"
    return None


def collect(source: Path, maximum_cost: int) -> list[tuple[str, str, str, int]]:
    parts_of_speech: dict[int, str] = {}
    for line in (source / "id.def").read_text(encoding="utf-8").splitlines():
        identifier, _, part_of_speech = line.partition(" ")
        parts_of_speech[int(identifier)] = part_of_speech

    source_files = sorted(source.glob("dictionary[0-9][0-9].txt"))
    if not source_files:
        raise ValueError("Mozc辞書ファイルがありません")

    costs: dict[tuple[str, str, str], int] = {}
    for source_file in source_files:
        with source_file.open(encoding="utf-8") as stream:
            for raw_line in stream:
                columns = raw_line.rstrip("\n").split("\t")
                if len(columns) < 5:
                    continue
                reading, left_id, _, cost_text, surface = columns[:5]
                if not CONVERTER.is_kana_reading(reading) or not surface:
                    continue
                cost = int(cost_text)
                if cost > maximum_cost:
                    continue
                word_class = adjective_class(
                    parts_of_speech.get(int(left_id), "")
                )
                if word_class is None:
                    continue
                key = (
                    CONVERTER.kana_to_romaji(reading),
                    surface,
                    word_class,
                )
                costs[key] = min(cost, costs.get(key, cost))

    return [
        (*key, costs[key])
        for key in sorted(costs, key=lambda key: (key[0], costs[key], key[1]))
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Mozc dictionary_ossディレクトリ")
    parser.add_argument("output", type=Path, help="出力するTSV")
    parser.add_argument("--maximum-cost", type=int, default=7000)
    arguments = parser.parse_args()
    try:
        entries = collect(arguments.source, arguments.maximum_cost)
    except (OSError, ValueError) as error:
        print(f"生成に失敗しました: {error}", file=sys.stderr)
        return 1
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(
        "".join(
            f"{reading}\t{surface}\t{word_class}\t{cost}\n"
            for reading, surface, word_class, cost in entries
        ),
        encoding="utf-8",
    )
    print(f"出力形容詞数: {len(entries)}")
    print(f"保存先: {arguments.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
