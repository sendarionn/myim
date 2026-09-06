# myim

myim は macOS 向けの Input Method です。[Gyaim](https://masui.github.io/GyaimMotion/)、[POBox](https://www.sonycsl.co.jp/projects/pobox-predictive-operation-based-on-example/)、[SKK](https://dic.nicovideo.jp/a/skk)にインスピレーションを受けて制作しました。推奨環境は macOS 15 以降です。

入力における「面倒」を解消するための様々な機能を搭載しています。
- [モードレスな日本語・英語入力](#モードレスな日本語英語入力)
- [シームレスな辞書登録](#シームレスな辞書登録)
- [Macの標準辞書や外部Webサイトで語義を確認する機能](#macの標準辞書や外部webサイトで語義を確認する機能)
- [翻訳モード](#翻訳モード)
- [計算機能](#計算機能)
- [カレンダー入力モード](#カレンダー入力モード)
- [単位変換機能](#単位変換機能)
- [絵文字の見え方をOS別に比較する機能](#絵文字の見え方をos別に比較できる機能)
- [記号の文字コード・名称を確認できる機能](#記号の文字コード名称を確認できる機能)
- [次の入力を予測・提案する機能](#次の入力を予測提案する機能)
- [誤入力を補完する機能](#誤入力を補完する機能)

## モードレスな日本語・英語入力

ローマ字から日本語と英語の候補を同時に生成するので、モードを切り替えることなく入力することができます。

![モードレスな日本語・英語入力](https://gyazo.com/5a290fed2bc04956510f1d327d2f6659.gif)

## シームレスな辞書登録

欲しい候補が辞書に存在しないときは、`⌥D`で辞書モードを起動できます。

![シームレスな辞書登録](https://gyazo.com/593987010a6a920fd7c7702054f00c8f.gif)

## Macの標準辞書や外部Webサイトで語義を確認する機能

Macの標準辞書や外部Webサイトで語義を確認できます。外部WebサイトはWikipediaなどの任意のサイトを検索子（`%s`）付きのURLで指定できます。

- 例：https://ja.wikipedia.org/wiki/%s

## 翻訳モード

`⌥T`で翻訳モードを起動し、入力した文章を丸ごと別の言語に翻訳できます。

![翻訳モード](https://gyazo.com/aabb1dff6de7035ab5aa5bf16c4bf1c0.gif)

## 計算機能

四則演算を入力すると計算結果を候補として表示します。

![計算機能](https://gyazo.com/eb51c24c9131085af417ba3cdea8cbef.gif)

## カレンダー入力モード

`⌥C`でカレンダー入力モードを起動し、日付を選択して入力できます。

![カレンダー入力モード](https://gyazo.com/f8d5e0f0c8d351745cee932550eec701.gif)

## 単位変換機能

距離・量・時間などの単位を変換した候補を表示します。

![単位変換](https://gyazo.com/c387f822ef5d5de0572420765dbe3649.gif)

## 絵文字の見え方をOS別に比較する機能

`⌥E`で絵文字ビューワを起動し、OS別の絵文字の見え方を比較できます。

![OS別の絵文字の見え方を比較できる機能](https://gyazo.com/775ed8254c27755d8b0b9a3b12f3e8b5.gif)

## 記号の文字コード・名称を確認できる機能

記号の文字コード・名称を表示します。



## 次の入力を予測・提案する機能

入力履歴から次の入力を予測し、候補として提案します。上手くいけば、最初の文字を入力した後は予測候補を選択するだけで文章が完成します。

![次の入力を予測・提案する機能](https://gyazo.com/4eb3cdfc307cfb80486c08ee501495ba.gif)

## 誤入力を補完する機能

多少の誤入力は補完・修正して候補を提案します。

![誤入力を補完する機能](https://gyazo.com/e13973783bfe72e23f4333db3bdff53e.gif)

## JavaScript拡張

次のフォルダへ`.js`ファイルを追加すると、入力に応じた候補を生成できます

```text
~/Library/Application Support/myim/Extensions/
```

標準では下記のサンプルコードが同梱されています。
- `datetime.js`
- `calendar.js`
- `nendo.js`：4月始まりの現在年度を西暦と和暦で生成
- `gengou.js`：現在の元号年を漢字表記と略号で生成

## ビルドとインストール

リポジトリをクローンして CD した後、下記コマンドを実行してください。Swift 6 以降が必要です。

```shell
./Scripts/install-macos-im.sh
```

インストール先は下記ディレクトリです。

```text
~/Library/Input Methods/myim.app
```

## 関連資料

- `HISTORY.md` 実装の更新履歴
- `MISCELLANEOUS.md` 入力変換と候補順の細かな調整
- `docs/DICTIONARY_DATASETS.md` 辞書の生成方法と実行時構成
- `docs/DICTIONARY_LICENSES.md` 辞書の出典とライセンス
- `docs/MACOS_DICTIONARY.md` macOS標準辞書の利用方針
