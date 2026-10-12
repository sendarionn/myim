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


def kana_to_dictionary_key(reading: str) -> str:
    result: list[str] = []
    index = 0
    geminate = False
    while index < len(reading):
        character = reading[index]
        if character == "っ":
            geminate = True
            index += 1
            continue
        if character == "ー":
            result.append("-")
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

    if geminate:
        result.append("xtsu")
    return "".join(result)
