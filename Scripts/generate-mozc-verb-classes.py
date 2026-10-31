#!/usr/bin/env python3
"""Mozcの自立動詞の基本形を、読み・表記・活用型・コストの表として出力する

myimのmozc-dictionary.tsvは品詞を持たないため、`知る`(五段)と`見る`(一段)の
ように語尾だけでは区別できない活用型を、変換時に参照できるようにする。

Mozcが`名詞,サ変接続`とする`記録`などの名詞は、「する」を付けたサ変動詞
`記録する`として出力し、動詞と同じ活用処理で`記録して`などを生成できるようにする。
"""

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

GODAN_ENDINGS = set("うくぐすつぬぶむる")


def verb_class(part_of_speech: str, reading: str, surface: str) -> str | None:
    fields = part_of_speech.split(",")
    if len(fields) < 6 or fields[0] != "動詞" or fields[1] != "自立":
        return None
    if fields[5] != "基本形":
        return None
    conjugation = fields[4]
    ending = reading[-1:]
    if conjugation.startswith("五段・カ行促音便"):
        return "godan-iku" if ending == "く" and surface.endswith("く") else None
    if conjugation.startswith("五段"):
        if ending in GODAN_ENDINGS and surface.endswith(ending):
            return "godan"
        return None
    if conjugation.startswith("一段"):
        return "ichidan" if reading.endswith("る") and surface.endswith("る") else None
    if conjugation.startswith("サ変"):
        if reading.endswith("する") and surface.endswith("する"):
            return "suru"
        if reading.endswith("ずる") and surface.endswith("ずる"):
            return "zuru"
        return None
    if conjugation.startswith("カ変"):
        if reading.endswith("くる") and surface.endswith(("来る", "くる")):
            return "kuru"
        return None
    return None


def suru_noun_verb(
    part_of_speech: str, reading: str, surface: str
) -> tuple[str, str] | None:
    """`名詞,サ変接続`の語を「する」を付けた読みと表記で返す

    `名詞,接尾,サ変接続`のような接尾語や一般の名詞は対象にしない
    """
    fields = part_of_speech.split(",")
    if len(fields) < 2 or fields[0] != "名詞" or fields[1] != "サ変接続":
        return None
    if reading.endswith("する") or surface.endswith("する"):
        return None
    return reading + "する", surface + "する"


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
                if not CONVERTER.is_kana_reading(reading):
                    continue
                cost = int(cost_text)
                if cost > maximum_cost:
                    continue
                part_of_speech = parts_of_speech.get(int(left_id), "")
                conjugation = verb_class(part_of_speech, reading, surface)
                if conjugation is None:
                    suru_verb = suru_noun_verb(part_of_speech, reading, surface)
                    if suru_verb is None:
                        continue
                    reading, surface = suru_verb
                    conjugation = "suru"
                key = (CONVERTER.kana_to_romaji(reading), surface, conjugation)
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
            f"{reading}\t{surface}\t{conjugation}\t{cost}\n"
            for reading, surface, conjugation, cost in entries
        ),
        encoding="utf-8",
    )
    print(f"出力動詞数: {len(entries)}")
    print(f"保存先: {arguments.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
