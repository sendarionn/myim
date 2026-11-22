# myim

myim は macOS 向けの Input Method です。[Gyaim](https://masui.github.io/GyaimMotion/)、[POBox](https://www.sonycsl.co.jp/projects/pobox-predictive-operation-based-on-example/)、[SKK](https://dic.nicovideo.jp/a/skk)にインスピレーションを受けて制作しました。推奨環境は macOS 15 以降です。

入力における「面倒」を解消するための様々な機能を搭載しています。ローマ字を入力すると候補が入力位置の近くに表示され、`Tab`で選択、`Return`で確定します。

## 主な特徴

**入力と変換**

- [モードレスな日本語と英語の入力](#モードレスな日本語と英語の入力)
- [誤入力の補正](#誤入力の補正)
- [次の入力の予測](#次の入力の予測)
- [再変換](#再変換)
- [候補フィルター](#候補フィルター)

**辞書と情報**

- [辞書登録](#辞書登録)
- [語義の確認](#語義の確認)
- [翻訳](#翻訳)
- [Web検索](#web検索)

**変換で使える特殊な候補**

- [計算](#計算)
- [単位変換](#単位変換)
- [記号の文字コードと名称](#記号の文字コードと名称)
- [日時候補](#日時候補)

**入力用のパネル**

- [日付入力](#日付入力)
- [時刻入力](#時刻入力)
- [絵文字パネル](#絵文字パネル)
- [選択文字列を括弧で囲む](#選択文字列を括弧で囲む)
- [ブックマーク検索](#ブックマーク検索)

**拡張と設定**

- [JavaScript拡張](#javascript拡張)
- [辞書の追加と更新](#辞書の追加と更新)
- [インストールと動作環境](#インストールと動作環境)

## モードレスな日本語と英語の入力

ローマ字から日本語と英語の候補を同時に表示するので、モードを切り替えずに入力できます。入力中は`F6`〜`F10`でひらがな、全角カタカナ、半角カタカナ、全角英数、半角大文字へ変換できます。

<!-- readme-media: modeless -->
![モードレスな日本語と英語の入力](docs/assets/modeless.gif)

## 誤入力の補正

設定で曖昧候補を有効にすると、多少の誤入力を補正した候補を第二パネルに表示します。`Shift`＋`Tab`で第二パネルの候補を選択できます。

<!-- readme-media: fuzzy -->
![誤入力の補正](docs/assets/fuzzy.gif)

## 次の入力の予測

確定した直後に、入力履歴から次の入力を予測して候補に表示します。不要な候補は選択中に`⌘X`で削除でき、履歴は設定からまとめて削除できます。

![次の入力の予測](https://gyazo.com/b8f6001f989132355b1c6665d77ef05c.gif)

## 再変換

確定済みの文字列を選択して`Tab`を押すと、候補を選び直せます。

<!-- readme-media: reconversion -->
![再変換](docs/assets/reconversion.gif)

## 候補フィルター

入力中に`⌥F`を押すと、含む文字、文字数、文字種、画数、意味などの条件で候補を絞り込めます。`「糸」を含む`のような条件では、部首や漢字の構成要素も検索します。

<!-- readme-media: filter -->
![候補フィルター](docs/assets/filter.gif)

## 辞書登録

欲しい候補が辞書にないときは、入力中に`⌥D`で辞書登録を開始できます。候補に表示する文字列と挿入する文字列を分けて登録でき、両者が異なる候補には候補パネルの右端に`●`が付きます。登録した候補は選択中に`⌘X`で削除できます。

![辞書登録](https://gyazo.com/463f422c915f0db1357492bb97805535.gif)

## 語義の確認

候補を選択すると、Macの標準辞書の語義を表示します。参照する辞書は設定の「表示するmacOS辞書」で選択できます。

<!-- readme-media: dictionary -->
![語義の確認](docs/assets/dictionary.gif)

外部情報パネルを有効にすると、外部Webサイトの検索結果も並べて表示します。検索先は`external-information.js`に検索子`%s`付きのURLで指定し、表示中のページは`⌥O`でブラウザで開けます。

![外部情報パネル](https://gyazo.com/55f609194a329b05c061008d230ffccd.gif)

## 翻訳

日本語の候補を選択すると、設定した翻訳先言語への翻訳候補を候補の隣に表示します。左右の矢印キーで翻訳候補へ移動して確定できます。macOSの翻訳機能を使うため、システム設定の「一般」>「言語と地域」>「翻訳言語」で日本語と翻訳先言語をダウンロードしておく必要があります。

## Web検索

設定でWeb検索を有効にすると、候補の選択中に`⌥W`で候補を確定してWeb検索を開きます。検索先は`websearch.js`で指定します。

## 計算

末尾に`=`を付けた四則演算の式を入力すると、計算結果を候補に表示します。

<!-- readme-media: calculation -->
![計算](docs/assets/calculation.gif)

## 単位変換

単位付きの数値を入力すると、関連する単位へ換算した候補を表示します。

<!-- readme-media: unit -->
![単位変換](docs/assets/unit.gif)

## 記号の文字コードと名称

記号の候補を選択すると、文字コードと名称を表示します。

<!-- readme-media: symbol -->
![記号の文字コードと名称](docs/assets/symbol.gif)

## 日時候補

`1330`や`13:30`のように時刻を入力すると、`13時30分`などの書式を候補に表示します。設定で日時候補を有効にすると、`kyou`や`ima`などの読みから現在の日付や時刻も入力できます。

<!-- readme-media: datetime -->
![日時候補](docs/assets/datetime.gif)

## 日付入力

`⌥C`でカレンダーを開き、矢印キーで日付を選んで`Return`を押すと、書式候補から選んで入力できます。

<!-- readme-media: calendar -->
![日付入力](docs/assets/calendar.gif)

## 時刻入力

`⌥T`で24時間のスライダーを開き、上のつまみで時刻を選択します。下のつまみを動かすと時間帯を選択でき、`Return`で表示される書式候補から選んで入力できます。

<!-- readme-media: time -->
![時刻入力](docs/assets/time.gif)

## 絵文字パネル

`⌥E`で絵文字パネルを開き、矢印キーや英字の検索で絵文字を選べます。選択した絵文字は肌の色などのバリエーションと、Apple、Android、Windowsでの見え方を表示します。

<!-- readme-media: emoji -->
![絵文字パネル](docs/assets/emoji.gif)

## 選択文字列を括弧で囲む

文字列を選択して`⌥Q`を押すと、括弧の一覧から選んだ括弧で囲みます。前回使った括弧が最初に選択されます。

<!-- readme-media: bracket -->
![選択文字列を括弧で囲む](docs/assets/bracket.gif)

## ブックマーク検索

`⌥B`でChromeのブックマークを検索し、URLやMarkdownリンクの書式を選んで入力できます。同梱のChrome拡張機能でブックマークを同期しておく必要があります。手順は[Chromeブックマークの同期](docs/DEVELOPMENT_INSTALLATION.md#chromeブックマークの同期)を参照してください。

## JavaScript拡張

`.js`ファイルを追加すると、入力に応じた候補を生成できます。拡張は入力メニューの「JavaScript拡張フォルダを開く」から開ける次のフォルダに置き、「JavaScript拡張を管理」で有効・無効を切り替えます。

```text
~/Library/Application Support/myim/extensions/
```

<!-- readme-media: extensions -->
![JavaScript拡張](docs/assets/extensions.gif)

標準で次の拡張が同梱されています。

- `nendo.js`：`nendo`で4月始まりの現在年度を西暦と和暦で生成
- `gengou.js`：`gengou`で現在の元号年を漢字表記と略号で生成
- `eto.js`：`eto`で今年の干支、十二支の読みから漢字と絵文字を生成
- `datetime.js`：日時の読みと、カレンダーで選択した日付の書式を生成
- `time.js`：時刻入力の書式と、時刻形式の入力の書式を生成
- `numeric-tools.js`：計算、二進数、ヤード・ポンド法への換算、分数の約分を生成
- `nextinput.js`：数字を確定した後に表示する単位の候補を定義
- `bookmarks.js`：ブックマーク検索の書式を定義
- `websearch.js`：Web検索の検索先を定義
- `external-information.js`：外部情報パネルの検索先を定義

## 辞書の追加と更新

設定の「辞書管理」から、SKK辞書をインポートして候補に加えたり、同梱の基本辞書（TKGJE）を最新版へ更新したりできます。インポートした辞書は辞書ごとに有効・無効を切り替えられます。

## インストールと動作環境

macOS 15 以降を推奨します。ビルドには Swift 6 以降が必要です。リポジトリをクローンしてcdした後、次のコマンドを実行してください。

```shell
./Scripts/install-macos-im.sh
```

インストール先は次のディレクトリです。

```text
~/Library/Input Methods/myim.app
```

インストール後、システム設定の「キーボード」で入力ソースにmyimを追加します。各機能の有効・無効は入力メニューの「myim設定」から、ショートカットは設定の「ショートカットキーを変更」から変更できます。パスワード入力欄で英字入力に切り替わった後にmyimへ自動で戻す設定もあります。

## 関連ドキュメント

- [HISTORY.md](HISTORY.md) 実装の更新履歴
- [MISCELLANEOUS.md](MISCELLANEOUS.md) 入力変換と候補順の細かな仕様
- [DESIGN.md](DESIGN.md) UI設計原則
- [docs/DEVELOPMENT_INSTALLATION.md](docs/DEVELOPMENT_INSTALLATION.md) 開発用インストールとChromeブックマークの同期
- [docs/DICTIONARY_DATASETS.md](docs/DICTIONARY_DATASETS.md) 辞書の生成方法と実行時構成
- [docs/DICTIONARY_LICENSES.md](docs/DICTIONARY_LICENSES.md) 辞書の出典とライセンス
- [docs/CANDIDATE_FILTER_IDS.md](docs/CANDIDATE_FILTER_IDS.md) 任意IDS構成要素データの導入方法
- [docs/JAPANESE_PARTICLE_SOURCES.md](docs/JAPANESE_PARTICLE_SOURCES.md) 助詞付き候補の参考資料
- [docs/MACOS_DICTIONARY.md](docs/MACOS_DICTIONARY.md) macOS標準辞書の利用方針
- [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) 同梱する第三者データとライセンスの一覧
