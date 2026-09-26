# 辞書ライセンス

アプリへ同梱する辞書以外の第三者データを含む一覧は
`THIRD_PARTY_NOTICES.md`を参照してください

## Mozc OSS辞書

- 用途: 日本語のかな漢字変換候補
- 出典: `google/mozc`の`src/data/dictionary_oss`
- 取得元: https://github.com/google/mozc
- 変換元リビジョン: `Sources/MyIMEMacOS/Resources/mozc-dictionary-source.json`
- 辞書固有の通知: `Sources/MyIMEMacOS/Resources/mozc-dictionary-NOTICE.txt`
- Mozcライセンス: `Sources/MyIMEMacOS/Resources/mozc-LICENSE.txt`

Mozc OSS辞書はIPAdic、沖縄辞書、Mozcで追加された語彙を含みます

配布時は辞書固有の通知とMozcライセンスをアプリへ同梱します

## TKG Japanese-English Learner's Dictionary

- 用途: 日本語学習者向けの日本語候補
- ライセンス: CC0 1.0
- 取得元: https://github.com/tkgally/je-dict-1
- 同梱ライセンス: `Sources/MyIMEMacOS/Resources/basic-dictionary-LICENSE.txt`

## 漢字フィルターデータ

- 用途: 部首と画数による候補フィルター
- 出典: Unicode Unihan 16.0.0
- 使用プロパティ: `kRSUnicode`、`kTotalStrokes`
- ライセンス: Unicode License v3、SPDX `Unicode-3.0`
- 同梱ライセンス: `Sources/MyIMEMacOS/Resources/UNICODE-LICENSE.txt`
- 生成情報: `Sources/MyIMEMacOS/Resources/kanji-filter-data-source.json`
- CHISE-IDSとCJKVI-IDSは同梱していません
- 利用者が任意に配置したIDSデータはアプリへ複製せず、配布元のライセンスを維持したまま読み込みます

## 記号辞書

- 用途: 記号名のローマ字入力から記号候補を生成
- 文字名称とコードポイントの確認元: Unicode Character Database 16.0.0 `NamesList.txt`
- 取得元: https://www.unicode.org/Public/16.0.0/ucd/NamesList.txt
- ライセンス: Unicode License v3、SPDX `Unicode-3.0`
- 同梱ライセンス: `Sources/MyIMEMacOS/Resources/UNICODE-LICENSE.txt`
- 生成情報: `Sources/MyIMEMacOS/Resources/symbol-dictionary-source.json`
- 日本語読みとローマ字入力の対応付け: myim独自データ

GPLのSKK-JISYO.Lは生成元として使用していません
