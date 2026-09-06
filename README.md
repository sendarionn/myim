# myim

myim は macOS 向けの Input Method です。[Gyaim](https://masui.github.io/GyaimMotion/)、[POBox](https://www.sonycsl.co.jp/projects/pobox-predictive-operation-based-on-example/)、[SKK](https://dic.nicovideo.jp/a/skk)にインスピレーションを受けて制作しました。推奨環境は macOS 15 以降です。

入力における「面倒」を解消するための様々な機能を搭載しています。
- [モードレスな日本語・英語入力](#モードレスな日本語英語入力)
- シームレスな辞書登録
- Macの標準辞書や外部Webサイトで入力文字列の意味を検索できる機能
- 翻訳モード
- 計算機能
- カレンダー入力モード
- 単位変換機能
- OS別の絵文字の見え方を確認できる機能
- 記号の文字コード・名称を確認できる機能
- そもそも入力するのが面倒
- 次の入力を提案する機能
- 誤入力を補完する機能
- 直前の文脈に合った候補を推薦する機能

## モードレスな日本語・英語入力

[モードレスな日本語・英語入力](https://gyazo.com/e737d9242b3e7583af93ed94c4368789.gif)



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
