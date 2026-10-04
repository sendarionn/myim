# 助詞付き候補の参考資料

`JapaneseParticleCandidateGenerator`で扱う助詞と助詞相当表現は、国際交流基金「みんなの教材サイト」の文法資料を参考に選定しています

## 参考資料

- [文法・文型で探す](https://www.kyozai.jpf.go.jp/kyozai/material/grammar/home/ja/render.do)
  - 基本的な助詞と、名詞へ接続する文法・文型の確認に使用
- [について／につき／については／についての](https://www.kyozai.jpf.go.jp/kyozai/material/BMA00007/ja/render.do)
  - `について`と`につき`の確認に使用
- [において／においては／における](https://www.kyozai.jpf.go.jp/kyozai/material/BMA00052/ja/render.do)
  - `において`の確認に使用
- [に対して／に対し／に対しては／に対する](https://www.kyozai.jpf.go.jp/kyozai/material/BMA00060/ja/render.do)
  - `に対して`の確認に使用
- [に関して／に関しては／に関する](https://www.kyozai.jpf.go.jp/kyozai/material/BMA00028/ja/render.do)
  - `に関して`の確認に使用
- [ごみの減量化](https://www.kyozai.jpf.go.jp/kyozai/material/DCH00004/ja/render.do)
  - `によって`、`において`、`にとって`、`を通じて`、`を通して`、`をめぐって`、`を受けて`などの確認に使用
- [さえ…ば](https://www.kyozai.jpf.go.jp/kyozai/material/BMA00040/ja/render.do)
  - 副助詞`さえ`の確認に使用
- [だけ](https://www.kyozai.jpf.go.jp/kyozai/material/BTS00037/ja/render.do)
  - 副助詞`だけ`の確認に使用
- [まで](https://www.kyozai.jpf.go.jp/kyozai/material/BMA00078/ja/render.do)
  - `まで`と他の助詞との接続の確認に使用

最終確認日: 2026-10-05

## 合成対象の棚卸し

### 単純結合を継続する表現

- 格助詞・係助詞等: `を`、`に`、`は`、`が`、`で`、`と`、`の`、`も`、`へ`、`や`、`か`
- 範囲・限定等: `から`、`まで`、`より`、`だけ`、`ほど`、`ばかり`、`しか`、`ぐらい`、`くらい`、`こそ`、`さえ`
- 文脈依存だが名詞等への接続が成立するもの: `ね`、`よ`
- 名詞句への接続を想定する複合表現: `にて`、`について`、`につき`、`に関して`、`に対して`、`によって`、`による`、`において`、`にとって`、`につれて`、`に比べて`、`として`、`のため`、`のために`、`を通じて`、`を通して`、`をめぐって`、`を受けて`

### 接続条件が必要な表現

- `ので`
- `のに`

`ので`と`のに`は動詞・形容詞等の述語へ接続できる一方、名詞には通常`な`等が必要です

現在の辞書は候補の品詞を保持しないため、単純な完全一致候補だけでは接続可否を安全に判定できません

今回は既存候補を広く失わないため維持し、将来、既存の活用型情報または軽量な接続属性で制限する対象とします

### 助詞合成器から除外した表現

- `て`

`て`は助詞として文字列結合せず、`VerbConjugationCandidateGenerator`と`VerbInflectionCandidateGenerator`が動詞活用型を確認して生成します

これにより、`shiteite`を`shitei + te`へ分割した`指定て`等を生成しません

## 利用範囲

資料本文を辞書データとして転載していません

myim内では、入力境界で検出する助詞・助詞相当表現の選定根拠として参照しています

実際の候補生成はmyim内のローマ字とひらがなの対応表、および既存辞書の完全一致検索から行います
