# 第三者データとライセンス

この文書はmyimへ同梱する第三者データの出典とライセンスをまとめたものです
myim本体へライセンスを付与する文書ではありません

## Unicode Unihan

- 用途: 漢字の部首と画数
- 版: Unicode Unihan 16.0.0
- 使用プロパティ: `kRSUnicode`、`kTotalStrokes`
- ライセンス: Unicode License v3、SPDX `Unicode-3.0`
- 取得元: https://www.unicode.org/Public/zipped/16.0.0/Unihan.zip
- 同梱ライセンス: `UNICODE-LICENSE.txt`
- 生成情報: `kanji-filter-data-source.json`

CHISE-IDSとCJKVI-IDSのデータは同梱していません
利用者が任意に追加したIDSデータはアプリへ複製せず、Application Support内の元ファイルから読み込みます
任意追加データには各配布元のライセンスが適用されます

## Unicode CLDR

- 用途: 絵文字の検索語
- ライセンス: Unicode License v3、SPDX `Unicode-3.0`
- 同梱ライセンス: `Emoji/CLDR-LICENSE.txt`

## Unicode Character Database

- 用途: 記号辞書に収録する文字の正式名称とコードポイントの確認
- 版: Unicode 16.0.0
- ライセンス: Unicode License v3、SPDX `Unicode-3.0`
- 取得元: https://www.unicode.org/Public/16.0.0/ucd/NamesList.txt
- 同梱ライセンス: `UNICODE-LICENSE.txt`
- 生成情報: `symbol-dictionary-source.json`

記号辞書の日本語読みとローマ字入力はmyim独自の対応付けです

## Noto Emoji

- 用途: Androidでの絵文字表示
- ライセンス: Apache License 2.0
- 同梱ライセンス: `Emoji/Android-LICENSE.txt`
- 出典情報: `Emoji/README.txt`

## Fluent UI Emoji

- 用途: Windowsでの絵文字表示
- ライセンス: MIT License
- 同梱ライセンス: `Emoji/Windows-LICENSE.txt`
- 出典情報: `Emoji/README.txt`

## Mozc OSS辞書

- 用途: 日本語のかな漢字変換候補
- 取得元: https://github.com/google/mozc
- 同梱ライセンス: `mozc-LICENSE.txt`
- 辞書固有の通知: `mozc-dictionary-NOTICE.txt`
- 生成情報: `mozc-dictionary-source.json`

## TKG Japanese-English Learner's Dictionary

- 用途: 基本辞書の日本語候補
- ライセンス: CC0 1.0 Universal
- 取得元: https://github.com/tkgally/je-dict-1
- 同梱ライセンス: `basic-dictionary-LICENSE.txt`
- 生成情報: `basic-dictionary-source.json`
