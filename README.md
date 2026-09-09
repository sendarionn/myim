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

![モードレスな日本語・英語入力](https://gyazo.com/68af79c934fe2b1f257d0ae5dc81e44f.gif)

## シームレスな辞書登録

欲しい候補が辞書に存在しないときは、`⌥D`で辞書モードを起動できます。

![シームレスな辞書登録](https://gyazo.com/463f422c915f0db1357492bb97805535.gif)

## Macの標準辞書で語義を確認する機能

Macの標準辞書で語義を確認できます。スーパー大辞林、New Oxford American Dictionary など複数の辞書を参照先として指定できます。

![Macの標準辞書で語義を確認する機能](https://gyazo.com/19ac28af4961209e279375b33005f4e9.gif)

## 外部Webサイトで語義を確認する機能

Macの標準辞書や外部Webサイトで語義を確認できます。外部WebサイトはWikipediaなどの任意のサイトを検索子（`%s`）付きのURLで指定できます。記述先のファイルは`../Library/Application Support/myim/extensions/external-information.js`です。

- 例：https://ja.wikipedia.org/wiki/%s

![外部Webサイトで語義を確認する機能](https://gyazo.com/55f609194a329b05c061008d230ffccd.gif)

## 翻訳モード

`⌥T`で翻訳モードを起動し、入力した文章を丸ごと別の言語に翻訳できます。

![翻訳モード](https://gyazo.com/14c7547a5ab66e568978962787fbc58d.gif)

## 計算機能

四則演算を入力すると計算結果を候補として表示します。

![計算機能](https://gyazo.com/cd4782c14191884b0628eb4bda7f933c.gif)

## カレンダー入力モード

`⌥C`でカレンダー入力モードを起動し、日付を選択して入力できます。

![カレンダー入力モード](https://gyazo.com/7f887690c2e19871a9975ad78eb4f84d.gif)

## 単位変換機能

距離・量・時間などの単位を変換した候補を表示します。

![単位変換](https://gyazo.com/80011e0c6e0da3855fabfab10df7be7f.gif)

## 絵文字の見え方をOS別に比較する機能

`⌥E`で絵文字ビューワを起動し、OS別の絵文字の見え方を比較できます。

![OS別の絵文字の見え方を比較できる機能](https://gyazo.com/97a4aa55d05783bf7c4a262b531e8781.gif)

## 記号の文字コード・名称を確認できる機能

記号の文字コード・名称を表示します。

![記号の文字コード・名称を確認できる機能](https://gyazo.com/f9b2fb62d0d381347ffd48657227fb5b.gif)

## 次の入力を予測・提案する機能

入力履歴から次の入力を予測し、候補として提案します。上手くいけば、最初の文字を入力した後は予測候補を選択するだけで文章が完成します。

![次の入力を予測・提案する機能](https://gyazo.com/b8f6001f989132355b1c6665d77ef05c.gif)

## 誤入力を補完する機能

多少の誤入力は補完・修正して候補を提案します。

![誤入力を補完する機能](https://gyazo.com/1395de111dc54ad00ffb0e8f425a05f2.gif)

## JavaScript拡張

次のフォルダへ`.js`ファイルを追加すると、入力に応じた動的な候補を生成できます

```text
~/Library/Application Support/myim/Extensions/
```

標準では下記のサンプルコードが同梱されています。
- `datetime.js`：`kyou`や`ashita`などの入力で対応した日付候補を生成
- `nendo.js`：`nendo`の入力で4月始まりの現在年度を西暦と和暦で生成
- `gengou.js`：`gengou`の入力で現在の元号年を漢字表記と略号で生成

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
