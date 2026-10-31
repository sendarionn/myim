# 辞書データ構成

## 採用構成

1つの辞書ですべてを扱わず、用途別のレイヤーとして組み合わせます

| データ | 用途 | 更新方法 |
| --- | --- | --- |
| Mozc OSS辞書 | 一般的な日本語変換の主辞書 | かな読みを入力表記に沿うローマ字inputへ変換して同梱 |
| TKGJE | 学習者向け日本語語彙の補助 | 同梱し、起動時に公開索引の更新を確認 |
| ローカルユーザー辞書 | 個人用語彙と優先候補 | IMから登録、削除 |

## Mozc OSS辞書

- `google/mozc`の`src/data/dictionary_oss`を使用
- かな読みをローマ字inputへ変換し、表記を候補として抽出
- 仮名読みの長音記号`ー`は辞書キーでも`-`として保持
- 候補コスト7000以下を対象に、1読み最大32候補へ削減
- 複合候補内のプレースホルダー`〜`と`～`を除去し、重複候補を統合
- 変換辞書本体に文脈ID、品詞、活用型は保持しない
- 文法的な接続判定に必要な形容動詞語幹と形容詞基本形だけを`mozc-adjective-classes.tsv`へ別途保持
- 279,666 input、382,203候補、約8.6MB

一般的な日本語語彙の網羅性が高いため、かな漢字変換の主辞書として使用します

変換元のリビジョンと条件は`Sources/MyIMEMacOS/Resources/mozc-dictionary-source.json`へ記録します

形容詞クラス表は同じリビジョンの`id.def`と`dictionaryNN.txt`から`Scripts/generate-mozc-adjective-classes.py`で生成します

- 保持項目: ローマ字読み、表記、形容詞クラス、コスト
- 対象クラス: 形容動詞語幹、形容詞基本形
- 対象コスト: 7000以下
- 同梱件数: 15,747件

辞書は入力に対応する正規inputだけを保持します
`si / shi`などの正しい表記差はランタイムの音節解析で正規化し、辞書へ重複展開しません

`きー`は`ki-`、`きい`は`kii`として別のキーにします
連続母音を一律に`-`へ置換せず、原データの仮名読みにある`ー`だけを変換します

## TKG Japanese-English Learner’s Dictionary

- ライセンスはCC0 1.0 Universal
- 商用利用、改変、再配布が可能
- 2026年7月28日12:34 UTCに取得した索引は29,993項目
- Basic、Core、Generalの語彙階層を収録
- 各項目に日本語見出し、かな読み、ローマ字化されたIDを収録
- AIによって作成・更新されているため、誤りが含まれる可能性を考慮する

myimではかな読みを入力表記に沿う辞書キーへ変換し、日本語見出しを候補として使用します

旧データとの互換用に、かな読みがない項目だけはローマ字化されたIDを使用します

通常変換用の基本辞書には英語の語義や用例を保持しません

```text
miru
 見る
 観る
 診る
```

### 変換

索引を取得します

```shell
curl -L \
  https://raw.githubusercontent.com/tkgally/je-dict-1/main/entries_index.json \
  -o /tmp/tkgje-entries-index.json
```

myim形式へ変換します

```shell
./Scripts/convert-tkgje-dictionary.py \
  /tmp/tkgje-entries-index.json \
  /tmp/tkgje-dictionary.tsv
```

BasicとCoreだけを取り込む場合は語彙階層を指定します

```shell
./Scripts/convert-tkgje-dictionary.py \
  /tmp/tkgje-entries-index.json \
  /tmp/tkgje-dictionary.tsv \
  --tiers basic core
```

2026年7月28日12:34 UTC版とmyim補完語彙を長音キー変換した同梱結果は次のとおりです

- 登録読み数 27,673
- 登録候補数 30,073
- 出力サイズ 約566KB

## 未採用の辞書候補

### UniDic

- 現代書き言葉UniDicはNew BSDを選択可能
- 語彙と読みの網羅性が高い
- CC0やパブリックドメインではない
- 配布時に著作権表示とライセンス表示が必要
- 最小の現行配布でも約530MB

基本辞書の不足を補う候補ですが、初期同梱データとしては大きすぎます

### JMdict

- 大規模で実績のある日本語辞書
- EDRDGが著作権を保持
- CC BY-SA系の条件がある
- パブリックドメインではない

myim本体や生成辞書の配布条件への影響を確認してから採用を判断します

## 英語データ

英語の予測候補はmacOSの`NSSpellChecker`から取得できます

外部データを同梱する場合は、Unlicenseの`dwyl/english-words`も候補になります

ただし単語頻度を持たないため、約47万語をそのまま利用すると一般的でない語が上位に出る問題があります

Webster’s Revised Unabridged Dictionary 1913はパブリックドメインですが、語義辞書であり入力候補の順位付けには別の頻度データが必要です

## 参照

- https://www.tkgje.jp/about.html
- https://github.com/tkgally/je-dict-1
- https://clrd.ninjal.ac.jp/unidic/en/back_number_en.html
- https://www.edrdg.org/
- https://github.com/dwyl/english-words
- https://www.crosswire.org/sword/modules/ModInfo.jsp?modName=Webster1913
