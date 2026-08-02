# 辞書ライセンス

## Mozc OSS辞書

- 用途: 日本語のかな漢字変換候補
- 出典: `google/mozc`の`src/data/dictionary_oss`
- 取得元: https://github.com/google/mozc
- 変換元リビジョン: `Sources/MyIMEMacOS/Resources/ime-dictionary-source.json`
- 辞書固有の通知: `Sources/MyIMEMacOS/Resources/ime-dictionary-LICENSE.txt`
- Mozcライセンス: `Sources/MyIMEMacOS/Resources/mozc-LICENSE.txt`

Mozc OSS辞書はIPAdic、沖縄辞書、Mozcで追加された語彙を含みます

配布時は辞書固有の通知とMozcライセンスをアプリへ同梱します

## TKG Japanese-English Learner's Dictionary

- 用途: 日本語学習者向けの日本語候補と英語候補
- ライセンス: CC0 1.0
- 取得元: https://github.com/jamsinclair/open-anki-jlpt-decks
- 同梱ライセンス: `Sources/MyIMEMacOS/Resources/basic-dictionary-LICENSE.txt`

## myim補完辞書

- 用途: 上流辞書で不足した語句の緊急補完と回帰確認
- 実装: `Sources/MyIMECore/SupplementalDictionary.swift`

上流辞書で候補を確認できた語句は重複除去されます
