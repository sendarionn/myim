#!/usr/bin/env python3
"""Mozcの人名候補のうち、語幹+助詞のほうが低コストになるものを列挙する

myimのTSVは品詞とコストを持たないため、`つぎの → 調`(人名・姓)のような
候補が`次 + の`の助詞合成より上位になる。Mozc本来のコストで語幹のほうが
安い人名だけを出力し、変換時に助詞合成の後ろへ回す。
"""

import argparse
import importlib.util
import sys
from collections import defaultdict
from pathlib import Path


CONVERTER_PATH = Path(__file__).with_name("convert-mozc-dictionary.py")
CONVERTER_SPEC = importlib.util.spec_from_file_location(
    "convert_mozc_dictionary", CONVERTER_PATH
)
CONVERTER = importlib.util.module_from_spec(CONVERTER_SPEC)
CONVERTER_SPEC.loader.exec_module(CONVERTER)

# JapaneseParticleCandidateGenerator.particlesの読み
PARTICLE_READINGS = [
    "wotsuujite", "wotooshite", "nikurabete", "nikanshite", "nitaisite",
    "nitsurete", "womegutte", "nitsuite", "notameni", "niyotte", "nioite",
    "nitotte", "toshite", "woukete", "nitsuki", "niyoru", "notame", "bakari",
    "shika", "gurai", "kurai", "dake", "hodo", "koso", "sae", "nite", "node",
    "noni", "kara", "made", "yori", "wo", "ni", "ha", "ga", "de", "to", "no",
    "mo", "he", "ya", "ka", "ne", "yo", "te",
]
MINIMUM_INPUT_LENGTH = 4
MINIMUM_STEM_LENGTH = 2


def person_name_ids(id_definition: Path) -> set[int]:
    identifiers: set[int] = set()
    for line in id_definition.read_text(encoding="utf-8").splitlines():
        identifier, _, part_of_speech = line.partition(" ")
        if "固有名詞,人名" in part_of_speech:
            identifiers.add(int(identifier))
    return identifiers


def collect(
    source: Path,
    maximum_cost: int,
) -> tuple[dict[str, dict[str, int]], set[tuple[str, str]]]:
    names = person_name_ids(source / "id.def")
    costs: dict[str, dict[str, int]] = defaultdict(dict)
    is_name: dict[tuple[str, str], bool] = {}
    source_files = sorted(source.glob("dictionary[0-9][0-9].txt"))
    if not source_files:
        raise ValueError("Mozc辞書ファイルがありません")
    for source_file in source_files:
        with source_file.open(encoding="utf-8") as stream:
            for raw_line in stream:
                columns = raw_line.rstrip("\n").split("\t")
                if len(columns) < 5:
                    continue
                reading, left_id, _, cost_text, candidate = columns[:5]
                candidate = CONVERTER.normalize_candidate(candidate)
                if not CONVERTER.is_kana_reading(reading) or not candidate:
                    continue
                if candidate == reading:
                    continue
                cost = int(cost_text)
                if cost > maximum_cost:
                    continue
                romaji = CONVERTER.kana_to_romaji(reading)
                key = (romaji, candidate)
                previous = costs[romaji].get(candidate)
                if previous is None or cost < previous:
                    costs[romaji][candidate] = cost
                is_name[key] = is_name.get(key, True) and int(left_id) in names
    person_names = {key for key, value in is_name.items() if value}
    return costs, person_names


def particle_shadowed_names(
    costs: dict[str, dict[str, int]],
    person_names: set[tuple[str, str]],
) -> list[tuple[str, str]]:
    result: list[tuple[str, str]] = []
    for reading, candidate in sorted(person_names):
        if len(reading) < MINIMUM_INPUT_LENGTH:
            continue
        name_cost = costs[reading][candidate]
        for particle in PARTICLE_READINGS:
            stem = reading[:-len(particle)]
            if not reading.endswith(particle) or len(stem) < MINIMUM_STEM_LENGTH:
                continue
            stem_costs = costs.get(stem)
            if stem_costs and min(stem_costs.values()) < name_cost:
                result.append((reading, candidate))
                break
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Mozc dictionary_ossディレクトリ")
    parser.add_argument("output", type=Path, help="出力するTSV")
    parser.add_argument("--maximum-cost", type=int, default=7000)
    arguments = parser.parse_args()
    try:
        costs, person_names = collect(arguments.source, arguments.maximum_cost)
        entries = particle_shadowed_names(costs, person_names)
    except (OSError, ValueError) as error:
        print(f"生成に失敗しました: {error}", file=sys.stderr)
        return 1
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(
        "".join(f"{reading}\t{candidate}\n" for reading, candidate in entries),
        encoding="utf-8",
    )
    print(f"出力候補数: {len(entries)}")
    print(f"保存先: {arguments.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
