# 外部辞書データの検討

## 結論

myimの基本変換辞書には、CC0のTKG Japanese-English Learner’s Dictionaryを採用します

Cosense辞書は全語彙を保持する場所ではなく、個人用の追加語彙と候補順の上書きに使用する構成が適切です

候補の優先順位は次のとおりです

1. Cosenseの個人辞書
2. TKGJEから生成した基本辞書
3. 英語入力時の`NSSpellChecker`補完

TKGJEから生成した辞書はアプリへ同梱し、起動時の更新確認でApplication Supportへ更新版を保存します

Cosenseはプロジェクトごとの拡張辞書としてローカルキャッシュします

## TKG Japanese-English Learner’s Dictionary

- ライセンスはCC0 1.0 Universal
- 商用利用、改変、再配布が可能
- 2026年7月28日12:34 UTCに取得した索引は29,993項目
- Basic、Core、Generalの語彙階層を収録
- 各項目に日本語見出し、かな読み、ローマ字化されたIDを収録
- AIによって作成・更新されているため、誤りが含まれる可能性を考慮する

myimではローマ字化されたIDを読み、日本語見出しを候補として使用できます

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
  /tmp/tkgje-dictionary.txt
```

BasicとCoreだけを取り込む場合は語彙階層を指定します

```shell
./Scripts/convert-tkgje-dictionary.py \
  /tmp/tkgje-entries-index.json \
  /tmp/tkgje-dictionary.txt \
  --tiers basic core
```

2026年7月28日12:34 UTC版の全件変換結果は次のとおりです

- 登録読み数 27,602
- 登録候補数 29,968
- 出力サイズ 約607KB

## 厳密なパブリックドメイン以外の候補

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
