#!/usr/bin/env python3

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path


KANA_TO_ROMAJI = {
    "きゃ": "kya", "きゅ": "kyu", "きぇ": "kye", "きょ": "kyo",
    "くぁ": "kwa", "くぃ": "kwi", "くぇ": "kwe", "くぉ": "kwo",
    "ぎゃ": "gya", "ぎゅ": "gyu", "ぎぇ": "gye", "ぎょ": "gyo",
    "ぐぁ": "gwa", "ぐぃ": "gwi", "ぐぇ": "gwe", "ぐぉ": "gwo",
    "しゃ": "sha", "しゅ": "shu", "しぇ": "she", "しょ": "sho",
    "じゃ": "ja", "じゅ": "ju", "じぇ": "je", "じょ": "jo",
    "ちゃ": "cha", "ちゅ": "chu", "ちぇ": "che", "ちょ": "cho",
    "てゃ": "tha", "てぃ": "thi", "てゅ": "thu", "てぇ": "the", "てょ": "tho",
    "でゃ": "dha", "でぃ": "dhi", "でゅ": "dhu", "でぇ": "dhe", "でょ": "dho",
    "とぁ": "twa", "とぃ": "twi", "とぅ": "twu", "とぇ": "twe", "とぉ": "two",
    "どぁ": "dwa", "どぃ": "dwi", "どぅ": "dwu", "どぇ": "dwe", "どぉ": "dwo",
    "つぁ": "tsa", "つぃ": "tsi", "つぇ": "tse", "つぉ": "tso",
    "にゃ": "nya", "にゅ": "nyu", "にぇ": "nye", "にょ": "nyo",
    "ひゃ": "hya", "ひゅ": "hyu", "ひぇ": "hye", "ひょ": "hyo",
    "ふぁ": "fa", "ふぃ": "fi", "ふぇ": "fe", "ふぉ": "fo",
    "びゃ": "bya", "びゅ": "byu", "びぇ": "bye", "びょ": "byo",
    "ぴゃ": "pya", "ぴゅ": "pyu", "ぴぇ": "pye", "ぴょ": "pyo",
    "みゃ": "mya", "みゅ": "myu", "みぇ": "mye", "みょ": "myo",
    "りゃ": "rya", "りゅ": "ryu", "りぇ": "rye", "りょ": "ryo",
    "いぇ": "ye", "うぁ": "wha", "うぃ": "wi", "うぇ": "we", "うぉ": "who",
    "ゔぁ": "va", "ゔぃ": "vi", "ゔぇ": "ve", "ゔぉ": "vo",
    "あ": "a", "い": "i", "う": "u", "え": "e", "お": "o",
    "か": "ka", "き": "ki", "く": "ku", "け": "ke", "こ": "ko",
    "が": "ga", "ぎ": "gi", "ぐ": "gu", "げ": "ge", "ご": "go",
    "さ": "sa", "し": "shi", "す": "su", "せ": "se", "そ": "so",
    "ざ": "za", "じ": "ji", "ず": "zu", "ぜ": "ze", "ぞ": "zo",
    "た": "ta", "ち": "chi", "つ": "tsu", "て": "te", "と": "to",
    "だ": "da", "ぢ": "di", "づ": "zu", "で": "de", "ど": "do",
    "な": "na", "に": "ni", "ぬ": "nu", "ね": "ne", "の": "no",
    "は": "ha", "ひ": "hi", "ふ": "fu", "へ": "he", "ほ": "ho",
    "ば": "ba", "び": "bi", "ぶ": "bu", "べ": "be", "ぼ": "bo",
    "ぱ": "pa", "ぴ": "pi", "ぷ": "pu", "ぺ": "pe", "ぽ": "po",
    "ま": "ma", "み": "mi", "む": "mu", "め": "me", "も": "mo",
    "や": "ya", "ゆ": "yu", "よ": "yo",
    "ら": "ra", "り": "ri", "る": "ru", "れ": "re", "ろ": "ro",
    "わ": "wa", "ゐ": "wi", "ゑ": "we", "を": "wo", "ゔ": "vu",
    "ぁ": "xa", "ぃ": "xi", "ぅ": "xu", "ぇ": "xe", "ぉ": "xo",
    "ゃ": "xya", "ゅ": "xyu", "ょ": "xyo", "ゎ": "xwa",
    "ゕ": "xka", "ゖ": "xke",
}


def kana_to_romaji(reading: str) -> str:
    result: list[str] = []
    index = 0
    geminate = False
    last_vowel = ""
    while index < len(reading):
        character = reading[index]
        if character == "っ":
            geminate = True
            index += 1
            continue
        if character == "ー":
            result.append(last_vowel or "-")
            index += 1
            continue
        if character == "ん":
            following = reading[index + 1:index + 2]
            following_romaji = KANA_TO_ROMAJI.get(following, "")
            result.append("n'" if following_romaji.startswith(tuple("aeiouy")) else "n")
            index += 1
            continue

        kana = reading[index:index + 2]
        romaji = KANA_TO_ROMAJI.get(kana)
        if romaji is not None:
            index += 2
        else:
            kana = character
            romaji = KANA_TO_ROMAJI.get(kana)
            index += 1
        if romaji is None:
            raise ValueError(f"ローマ字へ変換できない読みです: {reading} ({kana})")
        if geminate:
            result.append("t" if romaji.startswith("ch") else romaji[0])
            geminate = False
        result.append(romaji)
        vowels = [value for value in romaji if value in "aeiou"]
        if vowels:
            last_vowel = vowels[-1]

    if geminate:
        result.append("xtsu")
    return "".join(result)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Mozc OSS辞書をmyimのかな漢字変換辞書へ変換"
    )
    parser.add_argument("source", type=Path, help="Mozc dictionary_ossディレクトリ")
    parser.add_argument("output", type=Path, help="出力するmozc-dictionary.tsv")
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
                input_value = kana_to_romaji(reading)
                previous = values[input_value].get(candidate)
                if previous is None or cost < previous:
                    values[input_value][candidate] = cost

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
        lines.extend(f"{reading}\t{candidate}" for candidate in candidates)
        candidate_count += len(candidates)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")
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
                "inputFormat": "canonical-romaji",
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
